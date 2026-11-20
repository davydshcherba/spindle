import Foundation

/// Tags and technical info read from an audio file. Everything is optional
/// because real-world files are missing tags all the time.
nonisolated struct TrackMetadata: Sendable, Equatable {
    var title: String?
    var artist: String?
    var albumArtist: String?
    var album: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval = 0
    var artworkData: Data?
}

/// Placeholders for tags a file doesn't have. Shown in the UI as-is.
nonisolated enum UnknownTag {
    static let artist = "Unknown Artist"
    static let album = "Unknown Album"
}

nonisolated enum TagParsing {
    /// "3", "3/12" and " 03 " all parse to 3.
    static func leadingInt(_ text: String) -> Int? {
        let digits = text.trimmingCharacters(in: .whitespaces).prefix(while: \.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    /// Pulls a plausible four-digit year out of "2024", "2024-05-01" or ISO timestamps.
    static func year(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 4, let year = Int(trimmed.prefix(4)), (1000...3000).contains(year) else {
            return nil
        }
        return year
    }

    /// "01 - Song Name.flac" → "Song Name"; used when a file has no title tag.
    static func title(fromFilename url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let stripped = base.replacing(#/^\s*\d{1,3}\s*[-–.)_]\s*/#, with: "")
        let result = stripped.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? base : result
    }
}
