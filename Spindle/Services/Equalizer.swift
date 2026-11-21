import Foundation
import Observation

/// The equalizer as the user sees it: on or off, ten band gains, and the name of the preset the
/// bands happen to match. Remembers its settings between launches and hands every change to the
/// audio thread through `parameters`.
@Observable
final class Equalizer {
    private(set) var isEnabled: Bool
    private(set) var gains: [Float]

    /// What the player's audio taps read. Shared, never replaced.
    @ObservationIgnored let parameters = EqualizerParameters()
    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "equalizer.enabled"
        static let gains = "equalizer.gains"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        if let saved = defaults.array(forKey: Keys.gains) as? [Double], saved.count == EqualizerBands.count {
            gains = saved.map { EqualizerBands.clamped(Float($0)) }
        } else {
            gains = EqualizerBands.flat
        }
        parameters.update(isEnabled: isEnabled, gains: gains)
    }

    /// The preset the bands match, or `nil` for a curve of the user's own.
    var preset: EqualizerPreset? { EqualizerPreset.allCases.first { $0.gains == gains } }

    var isFlat: Bool { gains.allSatisfy { $0 == 0 } }

    /// On, and actually changing the sound.
    var isShapingSound: Bool { isEnabled && !isFlat }

    func setEnabled(_ value: Bool) {
        guard value != isEnabled else { return }
        isEnabled = value
        commit()
    }

    /// Moving a band turns the equalizer on: there would be nothing to hear otherwise.
    func setGain(_ decibels: Float, forBand band: Int) {
        guard gains.indices.contains(band) else { return }
        let value = EqualizerBands.clamped(decibels)
        guard value != gains[band] else { return }
        gains[band] = value
        isEnabled = true
        commit()
    }

    /// Choosing a preset turns the equalizer on, except "Flat", which leaves it as it is.
    func apply(_ preset: EqualizerPreset) {
        gains = preset.gains
        if preset != .flat { isEnabled = true }
        commit()
    }

    func reset() { apply(.flat) }

    private func commit() {
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(gains.map(Double.init), forKey: Keys.gains)
        parameters.update(isEnabled: isEnabled, gains: gains)
    }
}
