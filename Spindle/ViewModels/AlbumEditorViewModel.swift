import Foundation
import Observation

/// State of the "Edit album" sheet: name, album artist, year and cover, applied to every song.
@Observable
final class AlbumEditorViewModel {
    var title: String
    var artist: String
    var year: String
    private(set) var cover: Change<String?> = .keep
    private(set) var coverMessage: String?

    let album: Album
    private let library: LibraryViewModel
    private let covers: CoverImporter

    init(album: Album, library: LibraryViewModel, covers: CoverImporter) {
        self.album = album
        self.library = library
        self.covers = covers
        title = album.title
        // "Unknown" is shown as a placeholder, so the user isn't asked to delete the words.
        artist = album.artist == UnknownTag.artist ? "" : album.artist
        year = album.year.map(String.init) ?? ""
    }

    var songCount: Int { album.tracks.count }

    /// The cover to preview: the new choice if any, else the current one (nil = no cover).
    var previewKey: String? {
        switch cover {
        case .keep: album.artworkKey
        case .set(let key): key
        }
    }

    var hasCover: Bool { previewKey != nil }

    private var result: Result<AlbumEdit, AlbumEdit.Problem> {
        AlbumEdit.validated(title: title, artist: artist, year: year, originalYear: album.year, cover: cover)
    }

    var problem: AlbumEdit.Problem? {
        if case .failure(let problem) = result { return problem }
        return nil
    }

    /// Set when the new name and artist match another album: saving merges the two.
    var mergeNotice: String? {
        guard case .success(let edit) = result else { return nil }
        let newID = Album.key(artist: edit.artist, title: edit.title)
        guard newID != album.id, let other = library.album(withID: newID) else { return nil }
        return "\u{201C}\(other.title)\u{201D} by \(other.artist) already exists. These songs will be added to it."
    }

    /// True when the fields are valid and something differs from what's stored.
    var canSave: Bool {
        guard case .success(let edit) = result else { return false }
        return edit.title != album.title || edit.artist != album.artist || edit.year != .keep || edit.cover != .keep
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

    /// Saves and returns the album's id afterwards, or nil if nothing was saved.
    func save() -> String? {
        guard canSave, case .success(let edit) = result else { return nil }
        return library.apply(edit, to: album)
    }
}
