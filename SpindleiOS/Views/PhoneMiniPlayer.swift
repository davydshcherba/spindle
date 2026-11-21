import SwiftUI

/// The player's small bar above the home indicator. Tap it to open the full player.
struct PhoneMiniPlayer: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let item = player.currentItem {
            HStack(spacing: 12) {
                // A new cover settles in over the old one when the track changes.
                Swap(id: item.artworkKey, style: .cover) {
                    ArtworkView(key: item.artworkKey, pixelSize: 112, cornerRadius: 10)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Swap(id: item.id, alignment: .leading) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                    }
                    Swap(id: item.id, alignment: .leading, delay: 0.04) {
                        Text(item.artist)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                PlayPauseButton(size: 44)
                IconButton(systemName: "forward.end.fill", size: 18, color: Theme.text, help: "Next") {
                    player.next()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 30)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .onTapGesture { app.presentNowPlaying() }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Open player") { app.presentNowPlaying() }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
