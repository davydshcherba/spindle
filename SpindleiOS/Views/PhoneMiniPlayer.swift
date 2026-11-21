import SwiftUI

/// The player's small bar, in the accessory slot above the tab bar. Tap it to open the full player.
struct PhoneMiniPlayer: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app
    /// Squeezed into the tab bar when it is minimised, roomy above it otherwise.
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let item = player.currentItem {
            let isInline = placement == .inline
            HStack(spacing: 12) {
                // A new cover settles in over the old one when the track changes.
                Swap(id: item.artworkKey, style: .cover) {
                    ArtworkView(key: item.artworkKey, pixelSize: 96, cornerRadius: 8)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Swap(id: item.id, alignment: .leading) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                    }
                    if !isInline {
                        Swap(id: item.id, alignment: .leading, delay: 0.04) {
                            Text(item.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PlayPauseButton(size: 34)
                if !isInline {
                    IconButton(systemName: "forward.end.fill", size: 16, color: Theme.text, help: "Next") {
                        player.next()
                    }
                }
            }
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .onTapGesture { app.presentNowPlaying() }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Open player") { app.presentNowPlaying() }
        }
    }
}
