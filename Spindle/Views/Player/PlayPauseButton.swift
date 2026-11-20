import SwiftUI

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The round accent play/pause button, used in the player bar and on Now Playing.
struct PlayPauseButton: View {
    @Environment(PlayerViewModel.self) private var player
    var size: CGFloat = 46

    var body: some View {
        Button { player.togglePlayPause() } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: player.isPlaying ? 0 : size * 0.02)
                .frame(width: size, height: size)
                .background(Theme.accent, in: Circle())
                .shadow(color: .black.opacity(0.3), radius: size * 0.16, y: size * 0.08)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!player.hasItem)
        .opacity(player.hasItem ? 1 : 0.55)
        .help(player.isPlaying ? "Pause" : "Play")
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

/// Shuffle · previous · play/pause · next · repeat.
struct TransportControls: View {
    @Environment(PlayerViewModel.self) private var player
    var playSize: CGFloat = 46
    var iconSize: CGFloat = 17
    var spacing: CGFloat = 26

    var body: some View {
        HStack(spacing: spacing) {
            IconButton(
                systemName: "shuffle", size: iconSize,
                color: player.isShuffled ? Theme.accentLight : Theme.muted,
                hoverColor: player.isShuffled ? Theme.accentLight : Theme.text,
                help: player.isShuffled ? "Shuffle: on" : "Shuffle: off"
            ) { player.toggleShuffle() }

            IconButton(
                systemName: "backward.end.fill", size: iconSize + 2, color: Theme.text,
                help: "Previous", isEnabled: player.hasItem
            ) { player.previous() }

            PlayPauseButton(size: playSize)

            IconButton(
                systemName: "forward.end.fill", size: iconSize + 2, color: Theme.text,
                help: "Next", isEnabled: player.hasItem
            ) { player.next() }

            IconButton(
                systemName: player.repeatMode == .one ? "repeat.1" : "repeat", size: iconSize,
                color: player.repeatMode == .off ? Theme.muted : Theme.accentLight,
                hoverColor: player.repeatMode == .off ? Theme.text : Theme.accentLight,
                help: repeatHelp
            ) { player.cycleRepeat() }
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
