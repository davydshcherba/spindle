import Foundation
import Observation

/// State of the "Edit info" sheet: the text fields, validation, and saving.
@Observable
final class TrackEditorViewModel {
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var year: String
    var trackNumber: String
    private(set) var cover: Change<String?> = .keep
    private(set) var coverMessage: String?

    let track: Track
    private let library: LibraryViewModel
    private let covers: CoverImporter
    private let original: TrackEdit

    init(track: Track, library: LibraryViewModel, covers: CoverImporter) {
        self.track = track
        self.library = library
        self.covers = covers
        self.original = track.currentEdit

        title = track.title
        // Placeholders stand in for "unknown", so the user isn't asked to delete the words.
        artist = track.artist == UnknownTag.artist ? "" : track.artist
        album = track.album == UnknownTag.album ? "" : track.album
        // Always shown as stored: clearing it would make it follow the artist and could move
        // the track out of its album.
        albumArtist = track.albumArtist
        year = track.year.map(String.init) ?? ""
        trackNumber = track.trackNumber.map(String.init) ?? ""
    }

    /// The cover to preview: the new choice if any, else the current one (nil = no cover).
    var previewKey: String? {
        switch cover {
        case .keep: track.artworkKey
        case .set(let key): key
        }
    }

    var hasCover: Bool { previewKey != nil }

    /// "Glass Rooms.flac"
    var fileName: String { URL(fileURLWithPath: track.filePath).lastPathComponent }

    /// "FLAC · 3:28 · 24.3 MB"
    var fileSummary: String {
        [track.fileExtension.uppercased(), TimeFormat.clock(track.duration), TimeFormat.fileSize(track.fileSize)]
            .joined(separator: " \u{00B7} ")
    }

    private var result: Result<TrackEdit, TrackEdit.Problem> {
        TrackEdit.validated(
            title: title, artist: artist, albumArtist: albumArtist, album: album, year: year, trackNumber: trackNumber,
            cover: cover
        )
    }

    var problem: TrackEdit.Problem? {
        if case .failure(let problem) = result { return problem }
        return nil
    }

    /// True when the fields are valid and differ from what's stored.
    var canSave: Bool {
        if case .success(let edit) = result { return edit != original }
        return false
    }

    func chooseCover() async {
        switch await covers.choose() {
        case .chosen(let key):
            cover = .set(key)
            coverMessage = nil
        case .notAnImage:
            coverMessage = "That file isn\u{2019}t a picture Spindle can read."
        case .cancelled:
            break
        }
    }

    func removeCover() {
        cover = .set(nil)
        coverMessage = nil
    }

    /// Returns whether anything was saved.
    @discardableResult
    func save() -> Bool {
        guard case .success(let edit) = result, edit != original else { return false }
        library.apply(edit, to: track)
        return true
    }
}
