import Foundation
import SwiftData

/// A single audio file in the library.
///
/// Metadata is cached here at import time so the library can be shown without
/// touching the files. The audio itself is Spindle's own copy, kept in the app's library
/// folder (see `LibraryFiles`) under `libraryFileName`.
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
    /// Where the song was imported from. Used for duplicate detection and display only; the
    /// original may since have moved or gone.
    var filePath: String
    /// Name of Spindle's copy inside the library folder. Nil only for a song from an older
    /// version that has not been copied in yet: `LibraryService.migrateLegacyTracks()` does that.
    var libraryFileName: String?
    /// Pointer to the original file, from before Spindle kept its own copies. Only the
    /// migration reads it; empty once the song has been copied in.
    var bookmarkData: Data
    /// Key into `ArtworkStore`; shared between tracks with identical cover art.
    var artworkKey: String?
    var dateAdded: Date

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
        libraryFileName: String?,
        bookmarkData: Data = Data(),
        artworkKey: String? = nil,
        dateAdded: Date = .now
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
        self.libraryFileName = libraryFileName
        self.bookmarkData = bookmarkData
        self.artworkKey = artworkKey
        self.dateAdded = dateAdded
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
            libraryFileName: libraryFileName
        )
    }
}
