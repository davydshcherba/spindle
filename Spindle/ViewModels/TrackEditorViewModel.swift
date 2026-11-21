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

    // MARK: Album

    /// An album that is already in the library, as offered by the Album field. An album is told
    /// apart by its artist as well as its title: two "Greatest Hits" are two separate choices.
    struct AlbumChoice: Identifiable, Equatable {
        /// `Album.key` of the album.
        let id: String
        let title: String
        let artist: String
        let trackCount: Int
        let artworkKey: String?

        init(_ album: Album) {
            id = album.id
            title = album.title
            artist = album.artist
            trackCount = album.tracks.count
            artworkKey = album.artworkKey
        }

        /// "Maren Volk · 2 songs"
        var detail: String { "\(artist) \u{00B7} \(TimeFormat.count(trackCount, "song"))" }
    }

    /// What saving would do with the song's album.
    enum AlbumOutcome: Equatable {
        /// The song stays where it is.
        case stays(AlbumChoice)
        /// The song joins an album that already exists.
        case joins(AlbumChoice)
        /// Nothing matches (title and artist), so saving creates a new album.
        case creates(title: String, artist: String)
    }

    /// Existing albums to pick from. With `filteredByTyping`, only those whose title or artist
    /// contains what's typed in the Album field (titles that start with it first); otherwise all
    /// of them. Alphabetical within each group.
    func albumChoices(filteredByTyping: Bool) -> [AlbumChoice] {
        let query = filteredByTyping ? album.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        func startsWithQuery(_ choice: AlbumChoice) -> Bool {
            !query.isEmpty && choice.title.range(of: query, options: options.union(.anchored)) != nil
        }
        let matching = library.allAlbums.map(AlbumChoice.init).filter { choice in
            query.isEmpty
                || choice.title.range(of: query, options: options) != nil
                || choice.artist.range(of: query, options: options) != nil
        }
        return matching.sorted { first, second in
            let (firstStarts, secondStarts) = (startsWithQuery(first), startsWithQuery(second))
            if firstStarts != secondStarts { return firstStarts }
            let order = first.title.localizedStandardCompare(second.title)
            if order != .orderedSame { return order == .orderedAscending }
            return first.artist.localizedStandardCompare(second.artist) == .orderedAscending
        }
    }

    /// Puts the song into an existing album: its title and, just as important, its artist.
    func choose(_ choice: AlbumChoice) {
        // A blank title is how "Unknown Album" is written in the field.
        album = choice.title == UnknownTag.album ? "" : choice.title
        albumArtist = choice.artist
    }

    var albumOutcome: AlbumOutcome {
        let identity = TrackEdit.albumIdentity(album: album, artist: artist, albumArtist: albumArtist)
        let key = Album.key(artist: identity.artist, title: identity.title)
        guard let existing = library.allAlbums.first(where: { $0.id == key }) else {
            return .creates(title: identity.title, artist: identity.artist)
        }
        return key == track.albumKey ? .stays(AlbumChoice(existing)) : .joins(AlbumChoice(existing))
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
