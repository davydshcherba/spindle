import SwiftUI

/// The equalizer's popover: an on/off switch, a preset menu and ten band sliders.
struct EqualizerPanel: View {
    @Environment(Equalizer.self) private var equalizer

    private static let sliderHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            bands
            footer
            Text("Boosting a band lowers the overall volume a little, so loud songs don\u{2019}t distort.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .padding(18)
        .frame(width: 520)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Equalizer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            Toggle(
                "Equalizer",
                isOn: Binding(get: { equalizer.isEnabled }, set: { equalizer.setEnabled($0) })
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(Theme.accent)
        }
    }

    // MARK: Bands

    private var bands: some View {
        HStack(alignment: .top, spacing: 0) {
            scale
            ForEach(0..<EqualizerBands.count, id: \.self) { band in
                let gain = equalizer.gains[band]
                VStack(spacing: 6) {
                    Text(Self.decibelText(gain))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(gain == 0 ? Theme.muted : Theme.text)
                        .frame(height: 14)
                    EqualizerBandSlider(value: gain, name: EqualizerBands.spokenLabel(band)) {
                        equalizer.setGain($0, forBand: band)
                    }
                    .frame(height: Self.sliderHeight)
                    Text(EqualizerBands.label(band))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(height: 14)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // Dimmed while off, but still adjustable: moving a band switches it on.
        .opacity(equalizer.isEnabled ? 1 : 0.55)
        .animation(Motion.quick, value: equalizer.isEnabled)
    }

    /// "+12 dB" at the top of the sliders, 0 in the middle, "−12 dB" at the bottom.
    private var scale: some View {
        VStack(spacing: 6) {
            Color.clear.frame(height: 14)
            VStack {
                Text("+12")
                Spacer()
                Text("0")
                Spacer()
                Text("\u{2212}12")
            }
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.muted)
            .frame(height: Self.sliderHeight)
            Color.clear.frame(height: 14)
        }
        .frame(width: 30, alignment: .leading)
        .accessibilityHidden(true)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            presetMenu
            Spacer()
            Button("Reset") { equalizer.reset() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(equalizer.isFlat ? Theme.muted : Theme.accentLight)
                .disabled(equalizer.isFlat)
        }
    }

    private var presetMenu: some View {
        Menu {
            ForEach(EqualizerPreset.allCases) { preset in
                Button {
                    equalizer.apply(preset)
                } label: {
                    if preset == equalizer.preset {
                        Label(preset.rawValue, systemImage: "checkmark")
                    } else {
                        Text(preset.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Preset: ").foregroundStyle(Theme.muted) + Text(equalizer.preset?.rawValue ?? "Custom").foregroundStyle(Theme.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Color.white.opacity(0.09), in: Capsule())
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// 0 → "0", 3 → "+3", −2.5 → "−2.5"
    static func decibelText(_ decibels: Float) -> String {
        guard decibels != 0 else { return "0" }
        let sign = decibels > 0 ? "+" : "\u{2212}"
        let magnitude = abs(decibels)
        return magnitude == magnitude.rounded() ? "\(sign)\(Int(magnitude))" : "\(sign)\(String(format: "%.1f", magnitude))"
    }
}

/// One vertical slider: drag the thumb, or click anywhere on the track to jump there.
/// The bar grows from the 0 dB line towards the thumb.
struct EqualizerBandSlider: View {
    let value: Float
    /// "1 kilohertz", for VoiceOver.
    let name: String
    let onChange: (Float) -> Void

    private static let thumbSize: CGFloat = 16
    private static let trackWidth: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let thumb = Self.thumbSize
            let travel = max(geometry.size.height - thumb, 1)
            let x = geometry.size.width / 2
            let span = EqualizerBands.range.upperBound - EqualizerBands.range.lowerBound
            let fraction = CGFloat((value - EqualizerBands.range.lowerBound) / span)
            let thumbY = thumb / 2 + travel * (1 - fraction)
            let centerY = thumb / 2 + travel / 2

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: Self.trackWidth, height: travel)
                    .position(x: x, y: centerY)
                // The 0 dB line.
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 14, height: 1.5)
                    .position(x: x, y: centerY)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: Self.trackWidth, height: max(abs(thumbY - centerY), 0.5))
                    .position(x: x, y: (thumbY + centerY) / 2)
                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .position(x: x, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let position = min(1, max(0, 1 - (drag.location.y - thumb / 2) / travel))
                    onChange(EqualizerBands.range.lowerBound + Float(position) * span)
                }
            )
        }
        .frame(width: 32)
        .accessibilityElement()
        .accessibilityLabel(name)
        .accessibilityValue(Text("\(EqualizerPanel.decibelText(value)) decibels"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(value + 1)
            case .decrement: onChange(value - 1)
            @unknown default: break
            }
        }
    }
}
