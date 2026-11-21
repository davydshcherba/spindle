import AudioToolbox
import Foundation
import os
import Synchronization

/// The equalizer's settings as the audio thread sees them. One instance is shared by the UI
/// (which writes) and by every playing tap (which read), so it never makes the audio thread wait.
nonisolated final class EqualizerParameters: @unchecked Sendable {
    struct Snapshot: Sendable, Equatable {
        var isEnabled = false
        var gains = EqualizerBands.flat
    }

    private let lock = OSAllocatedUnfairLock(initialState: Snapshot())
    /// Bumped on every change, so the audio thread can tell cheaply that there is news.
    private let revision = Atomic<Int>(0)
    private let frames = Atomic<Int>(0)

    func update(isEnabled: Bool, gains: [Float]) {
        lock.withLock { $0 = Snapshot(isEnabled: isEnabled, gains: gains) }
        _ = revision.wrappingAdd(1, ordering: .releasing)
    }

    var currentRevision: Int { revision.load(ordering: .acquiring) }

    /// For the audio thread: `nil` if the UI happens to be writing right now. Try again next buffer.
    func snapshotIfAvailable() -> Snapshot? { lock.withLockIfAvailable { $0 } }

    /// How many frames of audio the equalizer has been able to work on since launch (audio in a
    /// format it can't process isn't counted).
    var processedFrames: Int { frames.load(ordering: .relaxed) }
    func recordProcessed(frames count: Int) { _ = frames.wrappingAdd(count, ordering: .relaxed) }
}

/// Ten peaking filters in a row, one per band, run over each channel of the audio.
///
/// Lives on the audio thread, so it allocates nothing while processing and never takes a lock it
/// would have to wait for. Each playing track gets its own processor (a filter remembers the
/// samples just before); they all read the same `EqualizerParameters`.
nonisolated final class EqualizerProcessor {
    private static let maxChannels = 8
    private static let valuesPerBand = 5
    /// One octave wide, so neighbouring bands overlap into a smooth curve.
    private static let quality = 2.0.squareRoot()
    /// Louder than this, samples are rounded off gently instead of hard-clipping.
    private static let kneeLevel: Float = 0.95

    private let parameters: EqualizerParameters
    private var sampleRate = 44_100.0
    private var canProcess = false
    private var appliedRevision = -1
    private var isActive = false
    private var outputGain: Float = 1

    /// b0, b1, b2, a1, a2 for each band, already divided by a0.
    private let coefficients: UnsafeMutablePointer<Double>
    /// Two delay values for each band and channel.
    private let state: UnsafeMutablePointer<Double>
    private let isBandActive: UnsafeMutablePointer<Bool>

    init(parameters: EqualizerParameters) {
        self.parameters = parameters
        coefficients = .allocate(capacity: EqualizerBands.count * Self.valuesPerBand)
        coefficients.initialize(repeating: 0, count: EqualizerBands.count * Self.valuesPerBand)
        state = .allocate(capacity: EqualizerBands.count * Self.maxChannels * 2)
        state.initialize(repeating: 0, count: EqualizerBands.count * Self.maxChannels * 2)
        isBandActive = .allocate(capacity: EqualizerBands.count)
        isBandActive.initialize(repeating: false, count: EqualizerBands.count)
    }

    deinit {
        coefficients.deallocate()
        state.deallocate()
        isBandActive.deallocate()
    }

    /// Called before the first buffer. Only 32-bit float audio is processed; anything else passes through.
    func prepare(sampleRate: Double, channelCount: Int, isFloat32: Bool) {
        self.sampleRate = sampleRate
        canProcess = isFloat32 && (1...Self.maxChannels).contains(channelCount) && sampleRate > 0
        appliedRevision = -1
        isActive = false
        state.update(repeating: 0, count: EqualizerBands.count * Self.maxChannels * 2)
        isBandActive.update(repeating: false, count: EqualizerBands.count)
    }

    /// One buffer: `frames` frames of `channels` interleaved channels (`channels == 1` for plain
    /// or non-interleaved audio). `firstChannel` says which channel a non-interleaved buffer is.
    func process(samples: UnsafeMutablePointer<Float>, frames: Int, channels: Int = 1, firstChannel: Int = 0) {
        guard canProcess, frames > 0 else { return }
        refreshIfNeeded()
        guard isActive else { return }
        for channel in 0..<channels {
            let index = min(firstChannel + channel, Self.maxChannels - 1)
            filter(samples + channel, frames: frames, stride: channels, channel: index)
        }
    }

    /// Runs every buffer of a block through the equalizer in place. Returns `false` if the audio
    /// is in a format the equalizer can't work with, and so was left untouched.
    @discardableResult
    func process(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int) -> Bool {
        guard canProcess else { return false }
        for (index, buffer) in buffers.enumerated() {
            guard let data = buffer.mData else { continue }
            let channels = max(1, Int(buffer.mNumberChannels))
            let available = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels)
            process(
                samples: data.assumingMemoryBound(to: Float.self),
                frames: min(frames, available),
                channels: channels,
                firstChannel: channels == 1 ? index : 0
            )
        }
        return true
    }

    // MARK: Settings

    private func refreshIfNeeded() {
        let latest = parameters.currentRevision
        guard latest != appliedRevision, let snapshot = parameters.snapshotIfAvailable() else { return }
        appliedRevision = latest
        apply(snapshot)
    }

    private func apply(_ snapshot: EqualizerParameters.Snapshot) {
        var largestBoost: Float = 0
        var anyBand = false
        for band in 0..<EqualizerBands.count {
            let gain = snapshot.isEnabled && band < snapshot.gains.count ? snapshot.gains[band] : 0
            let frequency = EqualizerBands.frequencies[band]
            // A flat band does nothing; a band near the top of the spectrum can't be built.
            guard abs(gain) >= 0.05, frequency < sampleRate * 0.45 else {
                isBandActive[band] = false
                continue
            }
            if !isBandActive[band] {
                state.advanced(by: band * Self.maxChannels * 2).update(repeating: 0, count: Self.maxChannels * 2)
            }
            isBandActive[band] = true
            setPeakingFilter(band: band, frequency: frequency, gain: Double(gain))
            largestBoost = max(largestBoost, gain)
            anyBand = true
        }
        isActive = anyBand
        // Boosting pushes loud music past full scale. Make room: lower everything by half of the
        // biggest boost (the soft knee catches whatever still gets through).
        outputGain = anyBand ? Float(pow(10, -Double(largestBoost) * 0.5 / 20)) : 1
    }

    /// The "peaking EQ" biquad from Robert Bristow-Johnson's Audio EQ Cookbook.
    private func setPeakingFilter(band: Int, frequency: Double, gain: Double) {
        let amplitude = pow(10, gain / 40)
        let omega = 2 * Double.pi * frequency / sampleRate
        let alpha = sin(omega) / (2 * Self.quality)
        let cosine = cos(omega)
        let a0 = 1 + alpha / amplitude
        let c = coefficients + band * Self.valuesPerBand
        c[0] = (1 + alpha * amplitude) / a0
        c[1] = -2 * cosine / a0
        c[2] = (1 - alpha * amplitude) / a0
        c[3] = -2 * cosine / a0
        c[4] = (1 - alpha / amplitude) / a0
    }

    // MARK: Filtering

    private func filter(_ samples: UnsafeMutablePointer<Float>, frames: Int, stride: Int, channel: Int) {
        for frame in 0..<frames {
            var value = Double(samples[frame * stride])
            for band in 0..<EqualizerBands.count where isBandActive[band] {
                let c = coefficients + band * Self.valuesPerBand
                let s = state + (band * Self.maxChannels + channel) * 2
                // Direct form II, transposed.
                let output = c[0] * value + s[0]
                s[0] = c[1] * value - c[3] * output + s[1]
                s[1] = c[2] * value - c[4] * output
                value = output
            }
            samples[frame * stride] = Self.softClip(Float(value) * outputGain)
        }
    }

    /// Leaves everything up to the knee alone and eases the rest towards, but never past, ±1.
    static func softClip(_ sample: Float) -> Float {
        let magnitude = abs(sample)
        guard magnitude > kneeLevel else { return sample }
        let room = 1 - kneeLevel
        let shaped = kneeLevel + room * tanh((magnitude - kneeLevel) / room)
        return sample < 0 ? -shaped : shaped
    }
}
