import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: UUID

    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let summary = playlists.summary(for: playlistID) {
            CollectionDetailView(
                backTitle: "Playlists",
                back: { app.show(.playlists) },
                kind: "PLAYLIST",
                title: summary.name,
                meta: "\(summary.detail) \u{00B7} updated \(TimeFormat.relative(summary.playlist.updatedAt))",
                tracks: summary.tracks,
                context: summary.name,
                emptyMessage: "This playlist is empty. Use the + button on any song to add it here.",
                onRemove: { playlists.remove([$0], from: summary.playlist) },
                onPlayed: { playlists.markPlayed(summary.id) }
            ) {
                PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 512, cornerRadius: 12)
            } moreMenu: {
                Button("Edit\u{2026}") { app.playlistEditor = .edit(summary.id) }
                Button("Delete Playlist\u{2026}", role: .destructive) { app.playlistPendingDeletion = summary.id }
            }
        } else {
            MissingItemView(message: "This playlist no longer exists.", backTitle: "Playlists") { app.show(.playlists) }
        }
    }
}

struct AlbumDetailView: View {
    let albumID: String

    @Environment(LibraryViewModel.self) private var library
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let album = library.album(withID: albumID) {
            CollectionDetailView(
                backTitle: "My Music",
                back: { app.show(.myMusic) },
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
                ArtworkView(key: album.artworkKey, pixelSize: 512, cornerRadius: 12)
            } moreMenu: {
                CollectionMenu(tracks: album.tracks, context: album.title)
                Divider()
                Button("Edit Album\u{2026}") { app.edit(album) }
            }
        } else {
            MissingItemView(message: "This album is no longer in your library.", backTitle: "My Music") { app.show(.myMusic) }
        }
    }
}

struct ArtistDetailView: View {
    let artistID: String

    @Environment(LibraryViewModel.self) private var library
    @Environment(AppViewModel.self) private var app

    var body: some View {
        if let artist = library.artist(withID: artistID) {
            CollectionDetailView(
                backTitle: "My Music",
                back: { app.show(.myMusic) },
                kind: "ARTIST",
                title: artist.name,
                meta: "\(TimeFormat.count(artist.albums.count, "album")) \u{00B7} \(TimeFormat.count(artist.trackCount, "track"))",
                tracks: artist.tracks,
                context: artist.name
            ) {
                ArtworkView(key: artist.artworkKey, pixelSize: 512, cornerRadius: 12)
            } moreMenu: {
                CollectionMenu(tracks: artist.tracks, context: artist.name)
            }
        } else {
            MissingItemView(message: "This artist is no longer in your library.", backTitle: "My Music") { app.show(.myMusic) }
        }
    }
}
