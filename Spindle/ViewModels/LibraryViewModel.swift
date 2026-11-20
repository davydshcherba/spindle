import Foundation
import Observation

/// Everything the My Music page shows: filtering, sorting, searching and the
/// derived album/artist groupings. Derived data is cached and only rebuilt when
/// the library or one of the inputs changes.
@Observable
final class LibraryViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case albums = "Albums"
        case artists = "Artists"
        case recentlyAdded = "Recently added"

        var id: Self { self }
    }

    enum Layout { case grid, list }

    enum Sort: String, CaseIterable, Identifiable {
        case recentlyAdded = "Recently added"
        case title = "Title"
        case artist = "Artist"
        case album = "Album"

        var id: Self { self }
    }

    /// How many of the newest tracks make up "Recently added".
    static let recentLimit = 50

    let library: LibraryService
    private let player: PlayerService

    var filter: Filter = .all
    var layout: Layout = .grid
    var sort: Sort = .recentlyAdded
    var searchText = ""

    private struct CacheKey: Equatable {
        let revision: Int
        let filter: Filter
        let sort: Sort
        let query: String
    }

    private struct Derived {
        let tracks: [Track]
        let albums: [Album]
        let artists: [ArtistGroup]
    }

    @ObservationIgnored private var derivedCache: (key: CacheKey, value: Derived)?
    @ObservationIgnored private var allAlbumsCache: (revision: Int, value: [Album])?

    init(library: LibraryService, player: PlayerService) {
        self.library = library
        self.player = player
    }

    // MARK: Output

    var visibleTracks: [Track] { derived.tracks }
    var visibleAlbums: [Album] { derived.albums }
    var visibleArtists: [ArtistGroup] { derived.artists }

    var isLibraryEmpty: Bool { library.tracks.isEmpty }
    var isSearching: Bool { !query.isEmpty }

    var hasNoResults: Bool {
        guard !isLibraryEmpty else { return false }
        switch (filter, layout) {
        case (.artists, .grid): return derived.artists.isEmpty
        case (_, .grid): return derived.albums.isEmpty
        case (_, .list): return derived.tracks.isEmpty
        }
    }

    /// "18 albums · 214 tracks · 14.2 GB"
    var summary: String {
        let tracks = library.tracks
        let size = tracks.reduce(Int64(0)) { $0 + $1.fileSize }
        return [
            TimeFormat.count(allAlbums.count, "album"),
            TimeFormat.count(tracks.count, "track"),
            TimeFormat.fileSize(size),
        ].joined(separator: " \u{00B7} ")
    }

    func album(withID id: String) -> Album? { allAlbums.first { $0.id == id } }
    func artist(withID id: String) -> ArtistGroup? { ArtistGroup.group(allAlbums).first { $0.id == id } }

    var errorMessage: String? { library.lastError }
    func dismissError() { library.dismissError() }

    // MARK: Actions

    func clearSearch() { searchText = "" }

    func remove(_ tracks: [Track]) {
        player.removeItems(withIDs: Set(tracks.map(\.id)))
        library.remove(tracks)
    }

    func removeAllMusic() { remove(library.tracks) }

    // MARK: Derivation

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var allAlbums: [Album] {
        if let cached = allAlbumsCache, cached.revision == library.revision { return cached.value }
        let value = Album.group(library.tracks)
        allAlbumsCache = (library.revision, value)
        return value
    }

    private var derived: Derived {
        let key = CacheKey(revision: library.revision, filter: filter, sort: sort, query: query)
        if let cached = derivedCache, cached.key == key { return cached.value }
        let value = compute()
        derivedCache = (key, value)
        return value
    }

    private func compute() -> Derived {
        let query = query
        let matches: (Track) -> Bool = { track in
            query.isEmpty
                || track.title.localizedStandardContains(query)
                || track.artist.localizedStandardContains(query)
                || track.album.localizedStandardContains(query)
        }
        let albumMatches: (Album) -> Bool = { album in
            query.isEmpty
                || album.title.localizedStandardContains(query)
                || album.artist.localizedStandardContains(query)
                || album.tracks.contains(where: matches)
        }

        var albums = allAlbums.filter(albumMatches)
        var tracks: [Track]

        switch filter {
        case .all:
            albums = ordered(albums, by: sort)
            tracks = orderedTracks(library.tracks.filter(matches), albums: albums, by: sort)
        case .albums:
            albums = ordered(albums, by: .title)
            tracks = albums.flatMap(\.tracks).filter(matches)
        case .artists:
            albums = ordered(albums, by: .artist)
            tracks = albums.flatMap(\.tracks).filter(matches)
        case .recentlyAdded:
            let recent = library.tracks.sorted { $0.dateAdded > $1.dateAdded }.prefix(Self.recentLimit)
            let recentIDs = Set(recent.map(\.id))
            tracks = recent.filter(matches)
            albums = ordered(allAlbums.filter { $0.tracks.contains { recentIDs.contains($0.id) } }.filter(albumMatches), by: .recentlyAdded)
        }

        let artists = filter == .artists
            ? ArtistGroup.group(albums).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            : []
        return Derived(tracks: tracks, albums: albums, artists: artists)
    }

    private func ordered(_ albums: [Album], by sort: Sort) -> [Album] {
        switch sort {
        case .recentlyAdded:
            return albums.sorted { $0.dateAdded > $1.dateAdded }
        case .title, .album:
            return albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist:
            return albums.sorted {
                let byArtist = $0.artist.localizedStandardCompare($1.artist)
                return byArtist == .orderedSame
                    ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    : byArtist == .orderedAscending
            }
        }
    }

    /// Track order for the list view. Title sorting is flat; everything else keeps albums together.
    private func orderedTracks(_ tracks: [Track], albums: [Album], by sort: Sort) -> [Track] {
        if sort == .title {
            return tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        let allowed = Set(tracks.map(\.id))
        return albums.flatMap(\.tracks).filter { allowed.contains($0.id) }
    }
}
