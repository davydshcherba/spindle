import Foundation

/// The ten bands of the equalizer: one per octave, from deep bass to air.
nonisolated enum EqualizerBands {
    /// Centre frequencies in Hz.
    static let frequencies: [Double] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    static let count = frequencies.count
    /// How far a band can be cut or boosted, in dB.
    static let range: ClosedRange<Float> = -12...12
    /// Bands move in half-decibel steps.
    static let step: Float = 0.5

    /// "31", "125", "1K", "16K"
    static func label(_ band: Int) -> String {
        let hertz = Int(frequencies[band])
        return hertz >= 1_000 ? "\(hertz / 1_000)K" : "\(hertz)"
    }

    /// "31 hertz", "1 kilohertz", for VoiceOver.
    static func spokenLabel(_ band: Int) -> String {
        let hertz = Int(frequencies[band])
        return hertz >= 1_000 ? "\(hertz / 1_000) kilohertz" : "\(hertz) hertz"
    }

    static let flat = [Float](repeating: 0, count: count)

    /// Snaps to the step and keeps it inside the range.
    static func clamped(_ decibels: Float) -> Float {
        let snapped = (decibels / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }
}

/// Ready-made curves. Each lists the gain of the ten bands in dB, lowest frequency first.
nonisolated enum EqualizerPreset: String, CaseIterable, Identifiable, Sendable {
    case flat = "Flat"
    case bassBoost = "Bass Booster"
    case bassReducer = "Bass Reducer"
    case trebleBoost = "Treble Booster"
    case vocal = "Vocal"
    case rock = "Rock"
    case pop = "Pop"
    case jazz = "Jazz"
    case classical = "Classical"
    case electronic = "Electronic"
    case hipHop = "Hip-Hop"
    case acoustic = "Acoustic"

    var id: String { rawValue }

    var gains: [Float] {
        switch self {
        case .flat:        EqualizerBands.flat
        case .bassBoost:   [6, 5, 4, 2.5, 1, 0, 0, 0, 0, 0]
        case .bassReducer: [-6, -5, -4, -2.5, -1, 0, 0, 0, 0, 0]
        case .trebleBoost: [0, 0, 0, 0, 0, 1, 2.5, 4, 5, 6]
        case .vocal:       [-3, -3, -2, 1, 3, 4, 4, 3, 1, 0]
        case .rock:        [4.5, 3.5, 2.5, 1, -1, -1.5, 0.5, 2.5, 3.5, 4.5]
        case .pop:         [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2]
        case .jazz:        [3, 2, 1, 2, -2, -2, 0, 1, 2, 3]
        case .classical:   [4, 3, 2, 2, -1, -1, 0, 2, 3, 3.5]
        case .electronic:  [5, 4, 1, 0, -2, 2, 1, 1, 4, 5]
        case .hipHop:      [5, 4, 1, 3, -1, -1, 1, -1, 2, 3]
        case .acoustic:    [4, 4, 3, 1, 2, 2, 3, 3, 3, 2]
        }
    }
}
