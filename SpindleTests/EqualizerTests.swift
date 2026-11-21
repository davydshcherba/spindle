import AudioToolbox
import Foundation
import Testing
@testable import Spindle

@MainActor
struct EqualizerTests {
    // MARK: Helpers

    private let sampleRate = 44_100.0

    private func sine(_ frequency: Double, amplitude: Float = 0.2, seconds: Double = 1) -> [Float] {
        (0..<Int(seconds * sampleRate)).map { index in
            amplitude * Float(sin(2 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }

    /// Loudness of the second half of a signal, after the filters have settled.
    private func settledRMS(_ samples: [Float]) -> Double {
        let tail = samples[(samples.count / 2)...]
        return (tail.reduce(0.0) { $0 + Double($1 * $1) } / Double(tail.count)).squareRoot()
    }

    private func decibels(_ ratio: Double) -> Double { 20 * log10(ratio) }

    /// One band set to `gain`, everything else flat.
    private func gains(band: Int, _ gain: Float) -> [Float] {
        var gains = EqualizerBands.flat
        gains[band] = gain
        return gains
    }

    private func makeProcessor(
        gains: [Float], isEnabled: Bool = true, sampleRate: Double = 44_100, channels: Int = 1, isFloat32: Bool = true
    ) -> (EqualizerProcessor, EqualizerParameters) {
        let parameters = EqualizerParameters()
        parameters.update(isEnabled: isEnabled, gains: gains)
        let processor = EqualizerProcessor(parameters: parameters)
        processor.prepare(sampleRate: sampleRate, channelCount: channels, isFloat32: isFloat32)
        return (processor, parameters)
    }

    private func run(_ input: [Float], through processor: EqualizerProcessor, channels: Int = 1) -> [Float] {
        var samples = input
        samples.withUnsafeMutableBufferPointer {
            processor.process(samples: $0.baseAddress!, frames: $0.count / channels, channels: channels)
        }
        return samples
    }

    private let oneKilohertzBand = 5

    // MARK: Sound

    @Test func aFlatEqualizerLeavesTheSoundAlone() {
        let (processor, _) = makeProcessor(gains: EqualizerBands.flat)
        let input = sine(1_000)
        #expect(run(input, through: processor) == input)
    }

    @Test func aSwitchedOffEqualizerLeavesTheSoundAlone() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12), isEnabled: false)
        let input = sine(1_000)
        #expect(run(input, through: processor) == input)
    }

    @Test func aBoostRaisesItsBandByTheGainMinusTheHeadroom() {
        // +12 dB at 1 kHz, less the 6 dB the equalizer gives back to keep loud songs from clipping.
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12))
        let input = sine(1_000)
        let change = decibels(settledRMS(run(input, through: processor)) / settledRMS(input))
        #expect(abs(change - 6) < 0.5, "expected about +6 dB, got \(change) dB")
    }

    @Test func aCutLowersItsBandWithoutAnyHeadroomChange() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, -12))
        let input = sine(1_000)
        let change = decibels(settledRMS(run(input, through: processor)) / settledRMS(input))
        #expect(abs(change + 12) < 0.5, "expected about -12 dB, got \(change) dB")
    }

    @Test func aBoostBarelyTouchesFarAwayFrequencies() {
        // 100 Hz is over three octaves below the boosted band: only the headroom (-6 dB) remains.
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12))
        let input = sine(100)
        let change = decibels(settledRMS(run(input, through: processor)) / settledRMS(input))
        #expect(abs(change + 6) < 0.8, "expected about -6 dB, got \(change) dB")
    }

    @Test func theOutputNeverGoesPastFullScale() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12))
        let output = run(sine(1_000, amplitude: 0.99), through: processor)
        #expect(output.allSatisfy { abs($0) <= 1 })
        #expect(output.contains { abs($0) > 0.95 }, "the test tone should be loud enough to reach the soft knee")
    }

    @Test func quietSoundIsNotTouchedBySoftClipping() {
        #expect(EqualizerProcessor.softClip(0.5) == 0.5)
        #expect(EqualizerProcessor.softClip(-0.9) == -0.9)
        // Past the knee it eases off: it keeps rising, but ever more slowly, and stops at full scale.
        #expect(EqualizerProcessor.softClip(1.2) > 0.97)
        #expect(EqualizerProcessor.softClip(1.2) < 1)
        #expect(EqualizerProcessor.softClip(-1.2) > -1)
        #expect(EqualizerProcessor.softClip(3) <= 1)
        #expect(EqualizerProcessor.softClip(-3) >= -1)
    }

    // MARK: Channels and formats

    @Test func stereoChannelsAreFilteredSeparately() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12), channels: 2)
        let tone = sine(1_000)
        // Left carries the tone, right is silent.
        let interleaved: [Float] = tone.flatMap { [$0, Float(0)] }
        let output = run(interleaved, through: processor, channels: 2)

        let left = stride(from: 0, to: output.count, by: 2).map { output[$0] }
        let right = stride(from: 1, to: output.count, by: 2).map { output[$0] }
        #expect(settledRMS(left) > settledRMS(tone))
        #expect(right.allSatisfy { $0 == 0 })
    }

    @Test func separateBuffersAreSeparateChannels() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12), channels: 2)
        var left = sine(1_000)
        var right = [Float](repeating: 0, count: left.count)
        let frames = left.count

        left.withUnsafeMutableBytes { leftBytes in
            right.withUnsafeMutableBytes { rightBytes in
                let list = AudioBufferList.allocate(maximumBuffers: 2)
                defer { free(list.unsafeMutablePointer) }
                list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(leftBytes.count), mData: leftBytes.baseAddress)
                list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(rightBytes.count), mData: rightBytes.baseAddress)
                processor.process(list, frames: frames)
            }
        }

        #expect(settledRMS(left) > 0.2 / 2.0.squareRoot(), "the left channel should be boosted")
        #expect(right.allSatisfy { $0 == 0 }, "silence in one channel must not leak into the other")
    }

    @Test func audioInAnUnsupportedFormatPassesThrough() {
        let (processor, _) = makeProcessor(gains: gains(band: oneKilohertzBand, 12), isFloat32: false)
        let input = sine(1_000)
        #expect(run(input, through: processor) == input)
    }

    @Test func aBandAboveWhatTheSampleRateCanCarryIsSkipped() {
        // At 22.05 kHz the 16 kHz band is out of reach.
        let (processor, _) = makeProcessor(gains: gains(band: 9, 12), sampleRate: 22_050)
        let input = sine(1_000)
        #expect(run(input, through: processor) == input)
    }

    // MARK: Changing it while music plays

    @Test func changesTakeEffectOnTheNextBuffer() {
        let (processor, parameters) = makeProcessor(gains: EqualizerBands.flat)
        let tone = sine(1_000)
        let before = run(tone, through: processor)
        #expect(before == tone)

        parameters.update(isEnabled: true, gains: gains(band: oneKilohertzBand, -12))
        let after = run(tone, through: processor)
        #expect(settledRMS(after) < settledRMS(tone) / 2, "a -12 dB cut should be heard on the next buffer")

        parameters.update(isEnabled: false, gains: gains(band: oneKilohertzBand, -12))
        #expect(run(tone, through: processor) == tone)
    }

    // MARK: Settings

    @Test func settingsSurviveARelaunch() {
        let defaults = UserDefaults(suiteName: "SpindleTests-\(UUID().uuidString)")!
        let equalizer = Equalizer(defaults: defaults)
        #expect(!equalizer.isEnabled)
        #expect(equalizer.isFlat)

        equalizer.setGain(4.5, forBand: 2)
        equalizer.setGain(-3, forBand: 8)

        let reopened = Equalizer(defaults: defaults)
        #expect(reopened.isEnabled)
        #expect(reopened.gains[2] == 4.5)
        #expect(reopened.gains[8] == -3)
        #expect(reopened.preset == nil)
    }

    @Test func movingABandSwitchesTheEqualizerOn() {
        let equalizer = Equalizer(defaults: UserDefaults(suiteName: "SpindleTests-\(UUID().uuidString)")!)
        equalizer.setGain(0, forBand: 3) // no change: nothing to turn on
        #expect(!equalizer.isEnabled)
        equalizer.setGain(2, forBand: 3)
        #expect(equalizer.isEnabled)
        #expect(equalizer.isShapingSound)
    }

    @Test func gainsAreSnappedAndLimited() {
        let equalizer = Equalizer(defaults: UserDefaults(suiteName: "SpindleTests-\(UUID().uuidString)")!)
        equalizer.setGain(30, forBand: 0)
        equalizer.setGain(-30, forBand: 1)
        equalizer.setGain(2.3, forBand: 2)
        #expect(equalizer.gains[0] == 12)
        #expect(equalizer.gains[1] == -12)
        #expect(equalizer.gains[2] == 2.5)
        equalizer.setGain(1, forBand: 99) // ignored, not a crash
    }

    @Test func presetsAreRecognisedAndResetClearsThem() {
        let equalizer = Equalizer(defaults: UserDefaults(suiteName: "SpindleTests-\(UUID().uuidString)")!)
        equalizer.apply(.rock)
        #expect(equalizer.isEnabled)
        #expect(equalizer.preset == .rock)
        equalizer.setGain(equalizer.gains[0] + 1, forBand: 0)
        #expect(equalizer.preset == nil, "an edited curve is \u{201C}Custom\u{201D}")

        equalizer.reset()
        #expect(equalizer.isFlat)
        #expect(equalizer.preset == .flat)
        #expect(!equalizer.isShapingSound)
    }

    @Test func everyPresetFitsTheBands() {
        for preset in EqualizerPreset.allCases {
            #expect(preset.gains.count == EqualizerBands.count, "\(preset.rawValue) needs one gain per band")
            #expect(preset.gains.allSatisfy { EqualizerBands.range.contains($0) }, "\(preset.rawValue) is out of range")
            #expect(preset.gains.map(EqualizerBands.clamped) == preset.gains, "\(preset.rawValue) must use half-dB steps")
        }
        #expect(Set(EqualizerPreset.allCases.map(\.gains)).count == EqualizerPreset.allCases.count, "presets should differ")
    }

    @Test func decibelsAreShownCompactly() {
        #expect(EqualizerPanel.decibelText(0) == "0")
        #expect(EqualizerPanel.decibelText(3) == "+3")
        #expect(EqualizerPanel.decibelText(-12) == "\u{2212}12")
        #expect(EqualizerPanel.decibelText(2.5) == "+2.5")
        #expect(EqualizerPanel.decibelText(-0.5) == "\u{2212}0.5")
    }

    // MARK: In the player

    @Test func theMusicActuallyPlaysThroughTheEqualizer() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait(try harness.makePlainTracks(count: 1, seconds: 3))

        let equalizer = Equalizer(defaults: harness.makeDefaults())
        equalizer.apply(.rock)
        let player = PlayerService(defaults: harness.makeDefaults(), equalizer: equalizer.parameters)
        player.volume = 0 // tests must never make noise

        player.play(harness.library.tracks.map(\.playerItem), context: "Test")
        #expect(player.isPlaying)

        let reached = await waitUntil { equalizer.parameters.processedFrames > 22_050 }
        #expect(reached, "audio should flow through the equalizer; frames so far: \(equalizer.parameters.processedFrames)")
        #expect(player.errorMessage == nil)
        player.stop()
    }

    @Test func everyFileFormatGoesThroughTheEqualizer() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])
        let items = harness.library.tracks.map(\.playerItem)
        #expect(items.count == 4, "the folder holds an M4A, an MP3, a FLAC and a WAV")

        let equalizer = Equalizer(defaults: harness.makeDefaults())
        equalizer.apply(.rock)
        let player = PlayerService(defaults: harness.makeDefaults(), equalizer: equalizer.parameters)
        player.volume = 0 // tests must never make noise

        for item in items {
            let before = equalizer.parameters.processedFrames
            player.play([item], context: "Test")
            let flowed = await waitUntil { equalizer.parameters.processedFrames > before + 8_820 }
            #expect(flowed, "\u{201C}\(item.title)\u{201D} should play through the equalizer")
            player.stop()
        }
    }
}
