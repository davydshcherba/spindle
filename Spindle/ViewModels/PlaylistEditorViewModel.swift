import Foundation
import Observation

/// State of the playlist sheet: create a playlist, or edit one's name and cover picture.
@Observable
final class PlaylistEditorViewModel {
    enum Mode: Equatable {
        case create(adding: [UUID])
        case edit(UUID)
    }

    var name: String
    private(set) var cover: Change<String?> = .keep
    private(set) var coverMessage: String?

    let mode: Mode
    private let playlists: PlaylistsViewModel
    private let covers: CoverImporter
    private let summary: PlaylistsViewModel.Summary?

    init(mode: Mode, playlists: PlaylistsViewModel, covers: CoverImporter) {
        self.mode = mode
        self.playlists = playlists
        self.covers = covers
        switch mode {
        case .create:
            summary = nil
            name = ""
        case .edit(let id):
            summary = playlists.summary(for: id)
            name = summary?.name ?? ""
        }
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var title: String { isCreating ? "New playlist" : "Edit playlist" }

    /// Covers to preview: the new picture, the automatic mosaic after "remove", or what's there now.
    var previewKeys: [String] {
        guard let summary else { return [] }
        switch cover {
        case .keep: return summary.artworkKeys
        case .set(let key?): return [key]
        case .set(nil): return summary.autoArtworkKeys
        }
    }

    /// Whether a picture of the user's own is (or will be) set.
    var hasCustomCover: Bool {
        switch cover {
        case .keep: summary?.coverKey != nil
        case .set(let key): key != nil
        }
    }

    var canSave: Bool {
        if isCreating { return true }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != summary?.name || cover != .keep
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

    /// Go back to the automatic mosaic.
    func useAutomaticCover() {
        cover = .set(nil)
        coverMessage = nil
    }

    /// Saves. Returns the id of a playlist that was just created empty, so it can be opened.
    @discardableResult
    func save() -> UUID? {
        guard canSave else { return nil }
        switch mode {
        case .create(let tracks):
            let playlist = playlists.create(named: name, adding: tracks)
            return tracks.isEmpty ? playlist.id : nil
        case .edit(let id):
            playlists.update(id, name: name, cover: cover)
            return nil
        }
    }
}
