import SwiftUI

/// The page behind a playlist, album or artist: big cover, title, Play/Shuffle, and the tracks.
struct CollectionDetailView<Cover: View, MoreMenu: View>: View {
    let backTitle: String
    let back: () -> Void
    /// "PLAYLIST", "ALBUM", "ARTIST"
    let kind: String
    let title: String
    var subtitle: String?
    let meta: String
    let tracks: [Track]
    let context: String
    var emptyMessage = "Nothing here yet."
    var onRemove: ((Track) -> Void)?
    var onPlayed: () -> Void = {}
    @ViewBuilder let cover: () -> Cover
    @ViewBuilder let moreMenu: () -> MoreMenu

    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Button(action: back) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text(backTitle)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)

                header

                if tracks.isEmpty {
                    emptyState
                } else {
                    TrackListView(tracks: tracks, context: context, onRemove: onRemove)
                }
            }
            .padding(.horizontal, Theme.pageInset)
            .padding(.top, 22)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 32) {
            cover()
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(kind)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                Text(title)
                    .font(.system(size: 54, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                }
                Text(meta)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                actions.padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                player.play(tracks, context: context)
                onPlayed()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(AccentButtonStyle(height: 48))

            Button {
                player.play(tracks, context: context, shuffled: true)
                onPlayed()
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }
            .buttonStyle(OutlineButtonStyle(height: 48))

            Menu {
                moreMenu()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
        .disabled(tracks.isEmpty)
        .opacity(tracks.isEmpty ? 0.5 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(emptyMessage)
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
            Button("Browse My Music") { app.show(.myMusic) }
                .buttonStyle(AccentButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}
