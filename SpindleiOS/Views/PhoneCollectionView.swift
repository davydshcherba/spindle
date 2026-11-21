import SwiftUI

/// A page a stack can push: the album, artist or playlist a `Route` names.
struct PhoneDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .album(let id): PhoneAlbumPage(albumID: id)
        case .artist(let id): PhoneArtistPage(artistID: id)
        case .playlist(let id): PhonePlaylistPage(playlistID: id)
        case .myMusic, .playlists: EmptyView()
        }
    }
}

/// The page behind an album, artist or playlist: the cover, title, Play and Shuffle, then the songs.
struct PhoneCollectionView<Cover: View, MoreMenu: View>: View {
    /// "ALBUM", "ARTIST", "PLAYLIST"
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

    var body: some View {
        List {
            header
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))

            if tracks.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                PhoneTrackRows(tracks: tracks, context: context, numbered: kind == "ALBUM", onRemove: onRemove)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .containerBackground(for: .navigation) { AmbientBackground() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu { moreMenu() } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("More")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            cover()
                .frame(maxWidth: 250)
                .shadow(color: .black.opacity(0.4), radius: 22, y: 12)

            VStack(spacing: 4) {
                Text(kind)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.accentLight)
                }
                Text(meta)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 12) {
                Button { start(shuffled: false) } label: {
                    Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(height: 48))
                Button { start(shuffled: true) } label: {
                    Label("Shuffle", systemImage: "shuffle").frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(height: 48))
            }
            .disabled(tracks.isEmpty)
            .opacity(tracks.isEmpty ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func start(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        player.play(tracks, context: context, shuffled: shuffled)
        onPlayed()
    }
}

// MARK: - The three kinds of page

struct PhoneAlbumPage: View {
    let albumID: String

    @Environment(LibraryViewModel.self) private var library
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let album = library.album(withID: albumID) {
            PhoneCollectionView(
                kind: "ALBUM",
                title: album.title,
                subtitle: album.artist,
                meta: [
                    TimeFormat.count(album.tracks.count, "track"),
                    TimeFormat.summary(album.duration),
                    album.year.map(String.init),
                ].compactMap { $0 }.joined(separator: " \u{00B7} "),
                tracks: album.tracks,
                context: album.title
            ) {
                ArtworkView(key: album.artworkKey, pixelSize: 512, cornerRadius: 14)
            } moreMenu: {
                CollectionMenu(tracks: album.tracks, context: album.title)
                Divider()
                Button("Edit Album\u{2026}") { app.edit(album) }
            }
        } else {
            ContentUnavailableView("This album is no longer in your library.", systemImage: "square.stack")
        }
    }
}

struct PhoneArtistPage: View {
    let artistID: String

    @Environment(LibraryViewModel.self) private var library

    var body: some View {
        if let artist = library.artist(withID: artistID) {
            PhoneCollectionView(
                kind: "ARTIST",
                title: artist.name,
                meta: "\(TimeFormat.count(artist.albums.count, "album")) \u{00B7} \(TimeFormat.count(artist.trackCount, "track"))",
                tracks: artist.tracks,
                context: artist.name
            ) {
                ArtworkView(key: artist.artworkKey, pixelSize: 512, cornerRadius: 14)
            } moreMenu: {
                CollectionMenu(tracks: artist.tracks, context: artist.name)
            }
        } else {
            ContentUnavailableView("This artist is no longer in your library.", systemImage: "person")
        }
    }
}

struct PhonePlaylistPage: View {
    let playlistID: UUID

    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let summary = playlists.summary(for: playlistID) {
            PhoneCollectionView(
                kind: "PLAYLIST",
                title: summary.name,
                meta: "\(summary.detail) \u{00B7} updated \(TimeFormat.relative(summary.playlist.updatedAt))",
                tracks: summary.tracks,
                context: summary.name,
                emptyMessage: "This playlist is empty. Use \u{201C}Add to Playlist\u{201D} on any song to put it here.",
                onRemove: { playlists.remove([$0], from: summary.playlist) },
                onPlayed: { playlists.markPlayed(summary.id) }
            ) {
                PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 512, cornerRadius: 14)
            } moreMenu: {
                Button("Edit\u{2026}") { app.playlistEditor = .edit(summary.id) }
                Button("Delete Playlist\u{2026}", role: .destructive) { app.playlistPendingDeletion = summary.id }
            }
        } else {
            ContentUnavailableView("This playlist no longer exists.", systemImage: "music.note.list")
        }
    }
}
