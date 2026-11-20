import SwiftUI

/// All playlists as a grid of mosaic covers, with a "New playlist" tile first.
struct PlaylistsView: View {
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app

    var body: some View {
        @Bindable var playlists = playlists

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Playlists")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.6)
                            .foregroundStyle(Theme.text)
                        Text(playlists.headerSummary)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    SortMenu(options: PlaylistsViewModel.Sort.allCases, selection: $playlists.sort)
                }

                LazyVGrid(columns: cardColumns, spacing: 30) {
                    NewPlaylistTile { app.newPlaylist() }
                    ForEach(playlists.summaries) { PlaylistCard(summary: $0) }
                }
            }
            .padding(.horizontal, Theme.pageInset)
            .padding(.top, 26)
            .padding(.bottom, 32)
        }
    }
}

private struct NewPlaylistTile: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 62, height: 62)
                                .background(Theme.accent, in: Circle())
                            Text("New playlist")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isHovering ? Theme.accentLight : Color.white.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                            )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a playlist")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Name it, then add songs")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.15), value: isHovering)
    }
}

struct PlaylistCard: View {
    let summary: PlaylistsViewModel.Summary

    @Environment(AppViewModel.self) private var app
    @Environment(PlayerViewModel.self) private var player
    @Environment(PlaylistsViewModel.self) private var playlists

    var body: some View {
        CoverCard(
            title: summary.name,
            subtitle: summary.detail,
            open: { app.navigate(to: .playlist(summary.id)) },
            play: { play(shuffled: false) }
        ) {
            PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 512, cornerRadius: 12)
        } menu: {
            Button("Play") { play(shuffled: false) }
            Button("Shuffle") { play(shuffled: true) }
            Divider()
            Button("Rename\u{2026}") { app.playlistEditor = .rename(summary.id) }
            Button("Delete\u{2026}", role: .destructive) { app.playlistPendingDeletion = summary.id }
        }
    }

    private func play(shuffled: Bool) {
        guard !summary.tracks.isEmpty else { return }
        player.play(summary.tracks, context: summary.name, shuffled: shuffled)
        playlists.markPlayed(summary.id)
    }
}
