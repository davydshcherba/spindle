import Foundation
import SwiftData

/// A single audio file in the library.
///
/// Metadata is cached here at import time so the library can be shown without
/// touching the files. The file itself is reached through `bookmarkData`, a
/// security-scoped bookmark, so access survives relaunches inside the sandbox.
@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    var fileSize: Int64
    var fileExtension: String
    /// Standardized path at import time. Used for duplicate detection and display only.
    var filePath: String
    var bookmarkData: Data
    /// Key into `ArtworkStore`; shared between tracks with identical cover art.
    var artworkKey: String?
    var dateAdded: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        albumArtist: String,
        album: String,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        duration: TimeInterval,
        fileSize: Int64,
        fileExtension: String,
        filePath: String,
        bookmarkData: Data,
        artworkKey: String? = nil,
        dateAdded: Date = .now,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.album = album
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.filePath = filePath
        self.bookmarkData = bookmarkData
        self.artworkKey = artworkKey
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
    }
}

extension Track {
    /// Groups tracks into albums: same album title by the same album artist.
    var albumKey: String { Album.key(artist: albumArtist, title: album) }

    /// Identity used to spot the same recording imported from two different paths.
    var contentKey: String {
        Self.contentKey(title: title, artist: artist, album: album, duration: duration)
    }

    static func contentKey(title: String, artist: String, album: String, duration: TimeInterval) -> String {
        [title, artist, album].map { $0.lowercased() }.joined(separator: "|") + "|\(Int(duration.rounded()))"
    }

    /// Lightweight, store-independent snapshot handed to the player.
    var playerItem: PlayerItem {
        PlayerItem(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            artworkKey: artworkKey,
            bookmarkData: bookmarkData
        )
    }
}
