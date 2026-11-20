import Foundation

/// The parts of a track the user can change. Edits live in Spindle's library only:
/// the app has read-only access to the user's files, so tags in the file are never rewritten.
nonisolated struct TrackEdit: Equatable, Sendable {
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var year: Int?
    var trackNumber: Int?
    /// A key into `ArtworkStore`; `.set(nil)` removes the song's cover.
    var cover: Change<String?> = .keep

    enum Problem: Error, Equatable, LocalizedError {
        case emptyTitle
        case invalidYear
        case invalidTrackNumber

        var errorDescription: String? {
            switch self {
            case .emptyTitle: "A song needs a title."
            case .invalidYear: "Year must be a four-digit number, like 2024."
            case .invalidTrackNumber: "Track number must be a whole number from 1 to 999."
            }
        }
    }

    /// Turns the text typed into an editor into a clean edit, or says what's wrong.
    ///
    /// - A blank artist or album becomes "Unknown Artist" / "Unknown Album", like an untagged file.
    /// - A blank album artist follows the artist.
    /// - A blank year or track number means "not set".
    static func validated(
        title: String, artist: String, albumArtist: String, album: String, year: String, trackNumber: String,
        cover: Change<String?> = .keep
    ) -> Result<TrackEdit, Problem> {
        guard let title = nonEmpty(title) else { return .failure(.emptyTitle) }
        let artist = nonEmpty(artist) ?? UnknownTag.artist
        let album = nonEmpty(album) ?? UnknownTag.album
        let albumArtist = nonEmpty(albumArtist) ?? artist

        var yearValue: Int?
        if let text = nonEmpty(year) {
            guard let value = Int(text), (1000...3000).contains(value) else { return .failure(.invalidYear) }
            yearValue = value
        }

        var trackValue: Int?
        if let text = nonEmpty(trackNumber) {
            guard let value = Int(text), (1...999).contains(value) else { return .failure(.invalidTrackNumber) }
            trackValue = value
        }

        return .success(TrackEdit(
            title: title, artist: artist, albumArtist: albumArtist, album: album,
            year: yearValue, trackNumber: trackValue, cover: cover
        ))
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Track {
    /// The track's current values, as an edit.
    var currentEdit: TrackEdit {
        TrackEdit(title: title, artist: artist, albumArtist: albumArtist, album: album, year: year, trackNumber: trackNumber)
    }
}
