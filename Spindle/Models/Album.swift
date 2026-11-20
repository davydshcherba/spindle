import Foundation

/// A derived grouping of tracks. Not persisted: it is rebuilt from the track list.
struct Album: Identifiable {
    let id: String
    let title: String
    let artist: String
    let year: Int?
    let artworkKey: String?
    /// Sorted by disc, then track number, then title.
    let tracks: [Track]
    let dateAdded: Date

    var duration: TimeInterval { tracks.reduce(0) { $0 + $1.duration } }

    nonisolated static func key(artist: String, title: String) -> String {
        artist.lowercased() + "\u{1F}" + title.lowercased()
    }

    static func group(_ tracks: [Track]) -> [Album] {
        Dictionary(grouping: tracks, by: \.albumKey).map { key, group in
            let sorted = group.sorted(by: Track.albumOrder)
            let first = sorted[0]
            return Album(
                id: key,
                title: first.album,
                artist: first.albumArtist,
                year: sorted.compactMap(\.year).min(),
                artworkKey: sorted.compactMap(\.artworkKey).first,
                tracks: sorted,
                dateAdded: sorted.map(\.dateAdded).max() ?? first.dateAdded
            )
        }
    }
}

/// A derived grouping of albums by artist.
struct ArtistGroup: Identifiable {
    let id: String
    let name: String
    let albums: [Album]

    var trackCount: Int { albums.reduce(0) { $0 + $1.tracks.count } }
    var artworkKey: String? { albums.lazy.compactMap(\.artworkKey).first }
    var tracks: [Track] { albums.flatMap(\.tracks) }
    var dateAdded: Date { albums.map(\.dateAdded).max() ?? .distantPast }

    static func group(_ albums: [Album]) -> [ArtistGroup] {
        Dictionary(grouping: albums, by: { $0.artist.lowercased() }).map { key, group in
            ArtistGroup(
                id: key,
                name: group[0].artist,
                albums: group.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            )
        }
    }
}

extension Track {
    /// Order of tracks within an album.
    static func albumOrder(_ a: Track, _ b: Track) -> Bool {
        let (da, db) = (a.discNumber ?? 1, b.discNumber ?? 1)
        if da != db { return da < db }
        let (ta, tb) = (a.trackNumber ?? .max, b.trackNumber ?? .max)
        if ta != tb { return ta < tb }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }
}
