import SwiftUI

/// The Playlists tab: every playlist as a cover, a tile to make a new one, and a page for each.
struct PhonePlaylistsView: View {
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app
    @Environment(PhoneNavigator.self) private var navigator

    private let columns = [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), alignment: .top)]

    var body: some View {
        @Bindable var playlists = playlists
        @Bindable var navigator = navigator

        NavigationStack(path: $navigator.playlistsPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    NewPlaylistTile { app.newPlaylist() }
                    ForEach(playlists.summaries) { PhonePlaylistCard(summary: $0) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .containerBackground(for: .navigation) { AmbientBackground() }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $playlists.sort) {
                            ForEach(PlaylistsViewModel.Sort.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.newPlaylist() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New playlist")
                }
            }
            .navigationDestination(for: Route.self) { PhoneDestination(route: $0) }
        }
    }
}

private struct NewPlaylistTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Theme.accent, in: Circle())
                            Text("New playlist")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
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
    }
}

private struct PhonePlaylistCard: View {
    let summary: PlaylistsViewModel.Summary

    @Environment(AppViewModel.self) private var app
    @Environment(PlayerViewModel.self) private var player
    @Environment(PlaylistsViewModel.self) private var playlists

    var body: some View {
        NavigationLink(value: Route.playlist(summary.id)) {
            VStack(alignment: .leading, spacing: 8) {
                PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 512, cornerRadius: 12)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(summary.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Play") { play(shuffled: false) }
            Button("Shuffle") { play(shuffled: true) }
            Divider()
            Button("Edit\u{2026}") { app.playlistEditor = .edit(summary.id) }
            Button("Delete\u{2026}", role: .destructive) { app.playlistPendingDeletion = summary.id }
        }
    }

    private func play(shuffled: Bool) {
        guard !summary.tracks.isEmpty else { return }
        player.play(summary.tracks, context: summary.name, shuffled: shuffled)
        playlists.markPlayed(summary.id)
    }
}
