import SwiftUI

/// The bar that floats at the bottom of every page: now playing, transport, progress, volume.
/// One Liquid Glass slab; the controls inside it are plain, because glass doesn't sit on glass.
struct PlayerBar: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            nowPlaying.frame(width: 300, alignment: .leading)
            transport.frame(maxWidth: .infinity)
            extras.frame(width: 300, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 84)
        .glassPanel(cornerRadius: 32)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: Left

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            Button { app.presentNowPlaying() } label: {
                ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 128, cornerRadius: 12)
                    .frame(width: 56, height: 56)
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
            } else {
                Text("Nothing playing")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Center

    private var transport: some View {
        VStack(spacing: 4) {
            TransportControls(playSize: 40, iconSize: 16, spacing: 22)

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
            IconButton(systemName: player.volumeSymbol, size: 16, help: player.isMuted ? "Unmute" : "Mute") {
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
            .frame(width: 104)
        }
    }
}
