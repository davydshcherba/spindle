import SwiftUI

/// Press feedback: the control dips slightly while held. Skipped for reduced motion.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(Motion.out(0.12), value: configuration.isPressed)
    }
}

/// The round accent play/pause button. In the player bar it is a solid accent circle (it sits
/// on a glass slab already); on Now Playing, with `glass`, it is an accent-tinted glass circle.
struct PlayPauseButton: View {
    @Environment(PlayerViewModel.self) private var player
    var size: CGFloat = 46
    var glass = false

    var body: some View {
        Button { player.togglePlayPause() } label: {
            symbol
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!player.hasItem)
        .opacity(player.hasItem ? 1 : 0.55)
        .help(player.isPlaying ? "Pause" : "Play")
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }

    @ViewBuilder private var symbol: some View {
        // The glyph morphs between play and pause instead of swapping.
        let image = Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            .contentTransition(.symbolEffect(.replace))
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .offset(x: player.isPlaying ? 0 : size * 0.02)
            .frame(width: size, height: size)
            .animation(Motion.quick, value: player.isPlaying)
        if glass {
            image.accentGlass(in: Circle())
        } else {
            image
                .background(Theme.accent, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: size * 0.16, y: size * 0.08)
        }
    }
}

/// Shuffle · previous · play/pause · next · repeat. With `glass`, every button gets its own
/// Liquid Glass circle (for Now Playing, where the controls float over the artwork backdrop).
struct TransportControls: View {
    @Environment(PlayerViewModel.self) private var player
    var playSize: CGFloat = 46
    var iconSize: CGFloat = 17
    var spacing: CGFloat = 26
    var glass = false

    private var diameter: CGFloat? { glass ? iconSize + 36 : nil }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: spacing) {
                IconButton(
                    systemName: "shuffle", size: iconSize,
                    color: player.isShuffled ? Theme.accentLight : Theme.muted,
                    hoverColor: player.isShuffled ? Theme.accentLight : Theme.text,
                    help: player.isShuffled ? "Shuffle: on" : "Shuffle: off",
                    glass: glass, diameter: diameter
                ) { player.toggleShuffle() }

                IconButton(
                    systemName: "backward.end.fill", size: iconSize + 2, color: Theme.text,
                    help: "Previous", isEnabled: player.hasItem, glass: glass, diameter: diameter
                ) { player.previous() }

                PlayPauseButton(size: playSize, glass: glass)

                IconButton(
                    systemName: "forward.end.fill", size: iconSize + 2, color: Theme.text,
                    help: "Next", isEnabled: player.hasItem, glass: glass, diameter: diameter
                ) { player.next() }

                IconButton(
                    systemName: player.repeatMode == .one ? "repeat.1" : "repeat", size: iconSize,
                    color: player.repeatMode == .off ? Theme.muted : Theme.accentLight,
                    hoverColor: player.repeatMode == .off ? Theme.text : Theme.accentLight,
                    help: repeatHelp, glass: glass, diameter: diameter
                ) { player.cycleRepeat() }
            }
        }
    }

    private var repeatHelp: String {
        switch player.repeatMode {
        case .off: "Repeat: off"
        case .all: "Repeat: all"
        case .one: "Repeat: one"
        }
    }
}
