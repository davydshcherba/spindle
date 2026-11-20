import Foundation

/// "Leave it alone" or "set it to this", for fields where `nil` is itself a valid value
/// (a year or cover can be cleared).
nonisolated enum Change<Value: Equatable & Sendable>: Equatable, Sendable {
    case keep
    case set(Value)
}

/// What can be changed about a whole album. Applies to every song in it.
///
/// Albums are not stored: an album is "all songs with this name by this album artist". So
/// renaming an album to match another one merges the two.
nonisolated struct AlbumEdit: Equatable, Sendable {
    var title: String
    var artist: String
    var year: Change<Int?>
    /// A key into `ArtworkStore`; `.set(nil)` removes the cover.
    var cover: Change<String?>

    enum Problem: Error, Equatable, LocalizedError {
        case emptyTitle
        case invalidYear

        var errorDescription: String? {
            switch self {
            case .emptyTitle: "An album needs a name."
            case .invalidYear: "Year must be a four-digit number, like 2024."
            }
        }
    }

    /// Turns what was typed into a clean edit. A blank album artist becomes "Unknown Artist".
    /// The year is only changed when it differs from `originalYear`.
    static func validated(
        title: String, artist: String, year: String, originalYear: Int?, cover: Change<String?>
    ) -> Result<AlbumEdit, Problem> {
        guard let title = nonEmpty(title) else { return .failure(.emptyTitle) }
        let artist = nonEmpty(artist) ?? UnknownTag.artist

        var yearChange: Change<Int?> = .keep
        if let text = nonEmpty(year) {
            guard let value = Int(text), (1000...3000).contains(value) else { return .failure(.invalidYear) }
            if value != originalYear { yearChange = .set(value) }
        } else if originalYear != nil {
            yearChange = .set(nil)
        }

        return .success(AlbumEdit(title: title, artist: artist, year: yearChange, cover: cover))
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
