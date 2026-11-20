import Foundation
import Observation

/// Playlist browsing and editing. Wraps `LibraryService` so views never touch
/// the persistence layer, and turns results into short toast messages.
@Observable
final class PlaylistsViewModel {
    enum Sort: String, CaseIterable, Identifiable {
        case recentlyPlayed = "Recently played"
        case recentlyUpdated = "Recently updated"
        case name = "Name"

        var id: Self { self }
    }

    /// A playlist with its tracks already resolved, ready to display.
    struct Summary: Identifiable {
        let playlist: Playlist
        let tracks: [Track]

        var id: UUID { playlist.id }
        var name: String { playlist.name }
        var trackCount: Int { tracks.count }
        var duration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }
        /// Up to four distinct covers of the songs inside, for the automatic 2×2 mosaic.
        let autoArtworkKeys: [String]
        /// The picture the user chose, if any.
        var coverKey: String? { playlist.coverKey }
        /// What to show: the chosen picture, otherwise the mosaic.
        var artworkKeys: [String] { coverKey.map { [$0] } ?? autoArtworkKeys }
        /// "32 tracks · 2 h 4 min"
        var detail: String {
            trackCount == 0
                ? "Empty"
                : "\(TimeFormat.count(trackCount, "track")) \u{00B7} \(TimeFormat.summary(duration))"
        }
    }

    var sort: Sort = .recentlyPlayed

    private let library: LibraryService
    private let toasts: ToastCenter

    @ObservationIgnored private var cache: (revision: Int, sort: Sort, value: [Summary])?

    init(library: LibraryService, toasts: ToastCenter) {
        self.library = library
        self.toasts = toasts
    }

    var summaries: [Summary] {
        if let cache, cache.revision == library.revision, cache.sort == sort { return cache.value }
        let built = library.playlists.map(makeSummary).sorted(by: order)
        cache = (library.revision, sort, built)
        return built
    }

    func summary(for id: UUID) -> Summary? { summaries.first { $0.id == id } }

    var totalTrackCount: Int { summaries.reduce(0) { $0 + $1.trackCount } }

    var headerSummary: String {
        "\(TimeFormat.count(summaries.count, "playlist")) \u{00B7} \(TimeFormat.count(totalTrackCount, "track"))"
    }

    func contains(_ track: Track, in playlist: Playlist) -> Bool {
        playlist.trackIDs.contains(track.id)
    }

    // MARK: Editing

    @discardableResult
    func create(named name: String, adding tracks: [UUID] = []) -> Playlist {
        let playlist = library.createPlaylist(named: name, adding: tracks)
        toasts.show(tracks.isEmpty ? "Created \u{201C}\(playlist.name)\u{201D}" : "Added to \u{201C}\(playlist.name)\u{201D}")
        return playlist
    }

    func rename(_ id: UUID, to name: String) {
        guard let playlist = library.playlists.first(where: { $0.id == id }) else { return }
        library.rename(playlist, to: name)
    }

    /// Saves a new name and/or cover picture.
    func update(_ id: UUID, name: String, cover: Change<String?>) {
        guard let playlist = library.playlists.first(where: { $0.id == id }) else { return }
        library.update(playlist, name: name, cover: cover)
    }

    func delete(_ id: UUID) {
        guard let playlist = library.playlists.first(where: { $0.id == id }) else { return }
        let name = playlist.name
        library.delete(playlist)
        toasts.show("Deleted \u{201C}\(name)\u{201D}")
    }

    func add(_ tracks: [Track], to playlist: Playlist) {
        let added = library.add(trackIDs: tracks.map(\.id), to: playlist)
        if added > 0 {
            toasts.show("Added to \u{201C}\(playlist.name)\u{201D}")
        } else {
            toasts.show(tracks.count == 1 ? "Already in \u{201C}\(playlist.name)\u{201D}" : "Those tracks are already in \u{201C}\(playlist.name)\u{201D}")
        }
    }

    func remove(_ tracks: [Track], from playlist: Playlist) {
        library.remove(trackIDs: Set(tracks.map(\.id)), from: playlist)
    }

    func markPlayed(_ id: UUID) {
        guard let playlist = library.playlists.first(where: { $0.id == id }) else { return }
        library.markPlayed(playlist)
    }

    // MARK: Helpers

    private func makeSummary(_ playlist: Playlist) -> Summary {
        let tracks = library.tracks(in: playlist)
        let keys = tracks.compactMap(\.artworkKey).removingDuplicates().prefix(4)
        return Summary(playlist: playlist, tracks: tracks, autoArtworkKeys: Array(keys))
    }

    private func order(_ a: Summary, _ b: Summary) -> Bool {
        switch sort {
        case .name:
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .recentlyUpdated:
            return a.playlist.updatedAt > b.playlist.updatedAt
        case .recentlyPlayed:
            let (pa, pb) = (a.playlist.lastPlayedAt ?? .distantPast, b.playlist.lastPlayedAt ?? .distantPast)
            return pa == pb ? a.playlist.updatedAt > b.playlist.updatedAt : pa > pb
        }
    }
}
