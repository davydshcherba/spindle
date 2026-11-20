import SwiftUI

/// The bottom bar that stays on every page: now playing, transport, progress, volume.
struct PlayerBar: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            nowPlaying.frame(width: 330, alignment: .leading)
            transport.frame(maxWidth: .infinity)
            extras.frame(width: 330, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .frame(height: 98)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: Left

    private var nowPlaying: some View {
        HStack(spacing: 16) {
            Button { app.presentNowPlaying() } label: {
                ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 128, cornerRadius: 6)
                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasItem)
            .help("Open Now Playing")
            .accessibilityLabel("Open Now Playing")

            if let item = player.currentItem {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(item.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                let isFavorite = player.currentTrack?.isFavorite == true
                IconButton(
                    systemName: isFavorite ? "heart.fill" : "heart", size: 16,
                    color: isFavorite ? Theme.accentLight : Theme.muted,
                    hoverColor: Theme.accentLight,
                    help: isFavorite ? "Remove from Liked" : "Add to Liked"
                ) { player.toggleFavoriteOfCurrent() }
            } else {
                Text("Nothing playing")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Center

    private var transport: some View {
        VStack(spacing: 6) {
            TransportControls(playSize: 46, iconSize: 17, spacing: 26)

            HStack(spacing: 12) {
                Text(player.elapsedText)
                    .frame(width: 44, alignment: .trailing)
                SeekBar(
                    progress: player.progress,
                    isEnabled: player.hasItem,
                    accessibilityName: "Playback position",
                    onBegan: { player.beginScrub() },
                    onChanged: { player.updateScrub($0) },
                    onEnded: { player.endScrub(at: $0) }
                )
                Text(player.durationText)
                    .frame(width: 44, alignment: .leading)
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: 620)
        }
    }

    // MARK: Right

    private var extras: some View {
        HStack(spacing: 6) {
            IconButton(systemName: "list.bullet", size: 16, help: "Queue", isEnabled: player.hasItem) {
                app.isQueueVisible = true
                app.presentNowPlaying()
            }
            IconButton(systemName: volumeSymbol, size: 16, help: player.isMuted ? "Unmute" : "Mute") {
                player.toggleMute()
            }
            SeekBar(
                progress: player.volume,
                thickness: 4,
                thumbSize: 12,
                fill: Theme.text,
                accessibilityName: "Volume",
                onChanged: { player.volume = $0 },
                onEnded: { player.volume = $0 }
            )
            .frame(width: 112)
        }
    }

    private var volumeSymbol: String {
        switch player.volume {
        case 0: "speaker.slash.fill"
        case ..<0.34: "speaker.wave.1.fill"
        case ..<0.67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}
