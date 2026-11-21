import Foundation
import Testing
@testable import Spindle

struct AlbumIdentityTests {
    @Test func aBlankTitleIsTheUnknownAlbum() {
        let identity = TrackEdit.albumIdentity(album: "  ", artist: "Maren Volk", albumArtist: "")
        #expect(identity.title == UnknownTag.album)
    }

    @Test func aBlankAlbumArtistFollowsTheSongsArtist() {
        #expect(TrackEdit.albumIdentity(album: "A", artist: " Maren Volk ", albumArtist: "").artist == "Maren Volk")
        #expect(TrackEdit.albumIdentity(album: "A", artist: "", albumArtist: "").artist == UnknownTag.artist)
    }

    @Test func anExplicitAlbumArtistWins() {
        let identity = TrackEdit.albumIdentity(album: "A", artist: "Maren Volk feat. X", albumArtist: "Maren Volk")
        #expect(identity.artist == "Maren Volk")
    }
}

/// Picking an album in the song editor: from the ones that exist (title and artist together),
/// or by typing a name for a new one.
@MainActor
struct TrackEditorAlbumTests {
    private func makeEditor(_ track: Track, _ rig: Rig) -> TrackEditorViewModel {
        let covers = CoverImporter(picker: FakePicker(image: nil), artwork: rig.harness.artwork)
        return TrackEditorViewModel(track: track, library: rig.library, covers: covers)
    }

    private func track(_ title: String, in rig: Rig) throws -> Track {
        try #require(rig.library.visibleTracks.first { $0.title == title })
    }

    @Test func everyExistingAlbumIsOfferedWhenNothingIsTyped() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = makeEditor(try track("Glass Rooms", in: rig), rig)

        let choices = editor.albumChoices(filteredByTyping: false)

        #expect(choices.map(\.title) == ["Low Tide Hours", "Paper Lanterns", UnknownTag.album])
        let lanterns = try #require(choices.first { $0.title == "Paper Lanterns" })
        #expect(lanterns.artist == "The Quiet Arcade")
        #expect(lanterns.trackCount == 1)
        #expect(lanterns.detail == "The Quiet Arcade \u{00B7} 1 song")
        let lowTide = try #require(choices.first { $0.title == "Low Tide Hours" })
        #expect(lowTide.detail == "Maren Volk \u{00B7} 2 songs")
    }

    @Test func typingNarrowsTheListByTitleOrArtist() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = makeEditor(try track("Glass Rooms", in: rig), rig)

        editor.album = "LANT"
        #expect(editor.albumChoices(filteredByTyping: true).map(\.title) == ["Paper Lanterns"])

        editor.album = "arcade"
        #expect(editor.albumChoices(filteredByTyping: true).map(\.title) == ["Paper Lanterns"], "the artist counts too")

        editor.album = "zzz"
        #expect(editor.albumChoices(filteredByTyping: true).isEmpty)
        #expect(editor.albumChoices(filteredByTyping: false).count == 3, "the arrow button still shows them all")
    }

    @Test func titlesThatStartWithWhatIsTypedComeFirst() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = makeEditor(try track("Glass Rooms", in: rig), rig)

        // "l" is inside all three titles (Low, Lanterns, Album), but only "Low Tide Hours" starts with it.
        editor.album = "l"
        let titles = editor.albumChoices(filteredByTyping: true).map(\.title)
        #expect(titles.first == "Low Tide Hours", "the only title starting with L goes first: \(titles)")
        #expect(Set(titles) == ["Low Tide Hours", "Paper Lanterns", UnknownTag.album], "the rest still match, further down")
    }

    @Test func pickingAnAlbumSetsItsTitleAndItsArtistTogether() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try track("Glass Rooms", in: rig)
        let editor = makeEditor(glass, rig)
        let lanterns = try #require(editor.albumChoices(filteredByTyping: false).first { $0.title == "Paper Lanterns" })

        editor.choose(lanterns)

        #expect(editor.album == "Paper Lanterns")
        #expect(editor.albumArtist == "The Quiet Arcade", "the artist comes along with the album")
        #expect(editor.artist == "Maren Volk", "the song's own artist is left alone")
        #expect(editor.canSave)
        #expect(editor.save())

        #expect(glass.album == "Paper Lanterns")
        #expect(glass.albumArtist == "The Quiet Arcade")
        #expect(glass.artist == "Maren Volk")
        let album = try #require(rig.library.album(withID: lanterns.id))
        #expect(album.tracks.count == 2, "the song joined the existing album instead of making a copy")
        #expect(rig.library.visibleAlbums.count == 3, "Low Tide Hours still has Undertow")
    }

    @Test func sameTitleByAnotherArtistIsAnotherAlbum() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try track("Glass Rooms", in: rig)
        let editor = makeEditor(glass, rig)

        // Maren Volk's song, typed into an album that exists only for The Quiet Arcade.
        editor.album = "Paper Lanterns"

        #expect(editor.albumOutcome == .creates(title: "Paper Lanterns", artist: "Maren Volk"))
        #expect(editor.save())
        #expect(rig.library.visibleAlbums.count == 4)
        #expect(rig.library.album(withID: Album.key(artist: "The Quiet Arcade", title: "Paper Lanterns"))?.tracks.count == 1)
        #expect(rig.library.album(withID: Album.key(artist: "Maren Volk", title: "Paper Lanterns"))?.tracks.count == 1)
    }

    @Test func typingANewNameCreatesANewAlbum() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try track("Glass Rooms", in: rig)
        let editor = makeEditor(glass, rig)

        editor.album = "Fresh Start"

        #expect(editor.albumOutcome == .creates(title: "Fresh Start", artist: "Maren Volk"))
        #expect(editor.save())
        let created = try #require(rig.library.album(withID: Album.key(artist: "Maren Volk", title: "Fresh Start")))
        #expect(created.tracks.map(\.title) == ["Glass Rooms"])
    }

    @Test func theHintSaysWhatSavingWillDo() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = makeEditor(try track("Glass Rooms", in: rig), rig)

        guard case .stays(let current) = editor.albumOutcome else {
            Issue.record("a song starts out in its own album, got \(editor.albumOutcome)")
            return
        }
        #expect(current.title == "Low Tide Hours")

        let lanterns = try #require(editor.albumChoices(filteredByTyping: false).first { $0.title == "Paper Lanterns" })
        editor.choose(lanterns)
        #expect(editor.albumOutcome == .joins(lanterns))

        editor.album = "Brand New"
        #expect(editor.albumOutcome == .creates(title: "Brand New", artist: "The Quiet Arcade"))
    }

    @Test func matchingIgnoresCaseLikeTheLibraryDoes() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = makeEditor(try track("Glass Rooms", in: rig), rig)

        editor.album = "paper lanterns"
        editor.albumArtist = "the quiet arcade"

        guard case .joins(let choice) = editor.albumOutcome else {
            Issue.record("expected to join the existing album, got \(editor.albumOutcome)")
            return
        }
        #expect(choice.title == "Paper Lanterns")
    }

    @Test func theUnknownAlbumIsWrittenAsABlankTitle() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try track("Glass Rooms", in: rig)
        let editor = makeEditor(glass, rig)
        let unknown = try #require(editor.albumChoices(filteredByTyping: false).first { $0.title == UnknownTag.album })

        editor.choose(unknown)

        #expect(editor.album == "", "blank is how the field says Unknown Album")
        #expect(editor.albumArtist == unknown.artist)
        #expect(editor.albumOutcome == .joins(unknown))
    }
}
