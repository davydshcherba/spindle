import Foundation
import MediaPlayer
import SwiftData
import Testing
@testable import Spindle

struct TrackEditValidationTests {
    private func validate(
        title: String = "Song", artist: String = "Artist", albumArtist: String = "", album: String = "Album",
        year: String = "", track: String = ""
    ) -> Result<TrackEdit, TrackEdit.Problem> {
        TrackEdit.validated(title: title, artist: artist, albumArtist: albumArtist, album: album, year: year, trackNumber: track)
    }

    @Test func trimsAndFillsDefaults() throws {
        let edit = try validate(title: "  Glass Rooms \n", artist: "  ", albumArtist: "", album: "").get()

        #expect(edit == TrackEdit(
            title: "Glass Rooms", artist: UnknownTag.artist, albumArtist: UnknownTag.artist,
            album: UnknownTag.album, year: nil, trackNumber: nil
        ))
    }

    @Test func blankAlbumArtistFollowsTheArtist() throws {
        let edit = try validate(artist: "Maren Volk", albumArtist: " ").get()
        #expect(edit.albumArtist == "Maren Volk")

        let explicit = try validate(artist: "Maren Volk feat. X", albumArtist: "Maren Volk").get()
        #expect(explicit.albumArtist == "Maren Volk")
    }

    @Test func emptyTitleIsRejected() {
        #expect(validate(title: "   ") == .failure(.emptyTitle))
    }

    @Test(arguments: [("2024", 2024), (" 1999 ", 1999), ("", nil)] as [(String, Int?)])
    func acceptsYears(text: String, expected: Int?) throws {
        #expect(try validate(year: text).get().year == expected)
    }

    @Test(arguments: ["24", "20x4", "99999", "0", "-2024", "20 24"])
    func rejectsYears(text: String) {
        #expect(validate(year: text) == .failure(.invalidYear))
    }

    @Test(arguments: [("3", 3), ("12", 12), ("", nil)] as [(String, Int?)])
    func acceptsTrackNumbers(text: String, expected: Int?) throws {
        #expect(try validate(track: text).get().trackNumber == expected)
    }

    @Test(arguments: ["0", "-1", "abc", "1000", "1.5"])
    func rejectsTrackNumbers(text: String) {
        #expect(validate(track: text) == .failure(.invalidTrackNumber))
    }

    @Test func theCoverChoiceIsPassedThroughUnchanged() throws {
        #expect(try validate().get().cover == .keep)
        let removed = TrackEdit.validated(
            title: "Song", artist: "A", albumArtist: "", album: "B", year: "", trackNumber: "", cover: .set(nil)
        )
        #expect(try removed.get().cover == .set(nil))
        let chosen = TrackEdit.validated(
            title: "Song", artist: "A", albumArtist: "", album: "B", year: "", trackNumber: "", cover: .set("key")
        )
        #expect(try chosen.get().cover == .set("key"))
    }

    @Test func problemsHaveReadableMessages() {
        #expect(TrackEdit.Problem.emptyTitle.localizedDescription.contains("title"))
        #expect(TrackEdit.Problem.invalidYear.localizedDescription.contains("four-digit"))
    }
}

@MainActor
struct TrackEditingTests {
    private func track(_ title: String, in rig: Rig) throws -> Track {
        try #require(rig.library.visibleTracks.first { $0.title == title })
    }

    @Test func editsAreSavedAndSurviveARelaunch() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let loose = try track("Loose Demo", in: rig)
        let revision = rig.harness.library.revision

        var edit = loose.currentEdit
        edit.title = "Loose Demo (2024 mix)"
        edit.artist = "Maren Volk"
        edit.year = 2024
        rig.library.apply(edit, to: loose)

        #expect(rig.harness.library.revision > revision, "derived lists must be rebuilt")
        let relaunched = LibraryService(modelContext: ModelContext(rig.harness.container), artwork: rig.harness.artwork, files: rig.harness.files)
        let saved = try #require(relaunched.tracks.first { $0.id == loose.id })
        #expect(saved.title == "Loose Demo (2024 mix)")
        #expect(saved.artist == "Maren Volk")
        #expect(saved.year == 2024)
    }

    @Test func movingATrackToAnotherAlbumRegroupsTheLibrary() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        #expect(rig.library.visibleAlbums.count == 3)
        let loose = try track("Loose Demo", in: rig)

        var edit = loose.currentEdit
        edit.album = "Paper Lanterns"
        edit.artist = "The Quiet Arcade"
        edit.albumArtist = "The Quiet Arcade"
        edit.trackNumber = 2
        rig.library.apply(edit, to: loose)

        #expect(rig.library.visibleAlbums.count == 2)
        let lanterns = try #require(rig.library.visibleAlbums.first { $0.title == "Paper Lanterns" })
        #expect(lanterns.tracks.map(\.title) == ["Lantern Song", "Loose Demo"])
    }

    @Test func editingAQueuedTrackUpdatesThePlayerAndNowPlaying() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks.sorted { $0.title < $1.title }
        let nowPlaying = NowPlayingService(player: rig.service, artwork: rig.harness.artwork)
        rig.player.play(tracks, context: "My Music")
        let slot = try #require(rig.service.currentEntry?.id)
        #expect(rig.player.currentItem?.title == "Glass Rooms")

        var edit = tracks[0].currentEdit
        edit.title = "Glass Rooms (Live)"
        edit.album = "Live at Low Tide"
        rig.library.apply(edit, to: tracks[0])

        withExtendedLifetime(nowPlaying) {
            #expect(rig.player.currentItem?.title == "Glass Rooms (Live)")
            #expect(rig.player.currentItem?.album == "Live at Low Tide")
            #expect(rig.service.currentEntry?.id == slot, "the queue slot must not change")
            #expect(rig.service.queue.count == tracks.count)
            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            #expect(info?[MPMediaItemPropertyTitle] as? String == "Glass Rooms (Live)")
            #expect(info?[MPMediaItemPropertyAlbumTitle] as? String == "Live at Low Tide")
        }
        rig.service.stop()
    }

    @Test func aSongCoverChangeReachesThePlayerAndNowPlaying() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks.sorted { $0.title < $1.title }
        rig.player.play(tracks, context: "My Music")
        #expect(rig.player.currentItem?.artworkKey == tracks[0].artworkKey)

        var edit = tracks[0].currentEdit
        edit.cover = .set("song-cover")
        rig.library.apply(edit, to: tracks[0])

        #expect(tracks[0].artworkKey == "song-cover")
        #expect(rig.player.currentItem?.artworkKey == "song-cover", "the player bar and Now Playing use the new cover")
        #expect(rig.service.queue.dropFirst().allSatisfy { $0.item.artworkKey != "song-cover" })

        edit.cover = .set(nil)
        rig.library.apply(edit, to: tracks[0])
        #expect(tracks[0].artworkKey == nil)
        #expect(rig.player.currentItem?.artworkKey == nil)
        rig.service.stop()
    }

    @Test func aCoverChangeAloneKeepsTheOtherFieldsAsTheyWere() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try track("Glass Rooms", in: rig)
        let before = glass.currentEdit

        var edit = glass.currentEdit
        edit.cover = .set("song-cover")
        rig.library.apply(edit, to: glass)

        var after = glass.currentEdit
        after.cover = .keep
        #expect(after == before)
    }

    @Test func editingATrackThatIsUpNextUpdatesTheQueueOnly() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks.sorted { $0.title < $1.title }
        rig.player.play(tracks, context: "My Music")

        var edit = tracks[1].currentEdit
        edit.title = "Renamed"
        rig.library.apply(edit, to: tracks[1])

        #expect(rig.player.currentItem?.title == "Glass Rooms")
        #expect(rig.player.upNext.first?.item.title == "Renamed")
        rig.service.stop()
    }
}

@MainActor
struct TrackEditorViewModelTests {
    private func makeEditor(_ track: Track, _ rig: Rig, image: URL? = nil) -> TrackEditorViewModel {
        let covers = CoverImporter(picker: FakePicker(image: image), artwork: rig.harness.artwork)
        return TrackEditorViewModel(track: track, library: rig.library, covers: covers)
    }

    private func writeImage(in rig: Rig, name: String = "song-cover.jpg") throws -> URL {
        let url = rig.harness.root.appending(path: name)
        try Fixtures.coverJPEG(red: 0.8, green: 0.2, blue: 0.5).write(to: url)
        return url
    }

    @Test func choosingAPictureChangesOnlyThatSongsCover() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks
        let glass = try #require(tracks.first { $0.title == "Glass Rooms" })
        let undertowCover = try #require(tracks.first { $0.title == "Undertow" }).artworkKey
        let editor = makeEditor(glass, rig, image: try writeImage(in: rig))
        let before = editor.previewKey
        #expect(before != nil && !editor.canSave)

        await editor.chooseCover()

        let chosen = try #require(editor.previewKey)
        #expect(chosen != before)
        #expect(rig.harness.artwork.image(forKey: chosen, maxPixelSize: 128) != nil, "the picture was stored")
        #expect(editor.canSave, "a new cover alone is enough to save")
        #expect(editor.save())
        #expect(glass.artworkKey == chosen)
        #expect(tracks.first { $0.title == "Undertow" }?.artworkKey == undertowCover, "other songs keep their cover")
    }

    @Test func removingTheCoverClearsItForThatSong() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try #require(rig.library.visibleTracks.first { $0.title == "Glass Rooms" })
        let editor = makeEditor(glass, rig)
        #expect(editor.hasCover)

        editor.removeCover()

        #expect(!editor.hasCover && editor.canSave)
        #expect(editor.save())
        #expect(glass.artworkKey == nil)
    }

    @Test func aFileThatIsNotAPictureIsReportedAndChangesNothing() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try #require(rig.library.visibleTracks.first { $0.title == "Glass Rooms" })
        let bad = rig.harness.root.appending(path: "fake.png")
        try Data("not a picture".utf8).write(to: bad)
        let editor = makeEditor(glass, rig, image: bad)

        await editor.chooseCover()

        #expect(editor.coverMessage?.contains("picture") == true)
        #expect(!editor.canSave)
        #expect(editor.previewKey == glass.artworkKey)
    }

    @Test func cancellingThePickerChangesNothing() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try #require(rig.library.visibleTracks.first { $0.title == "Glass Rooms" })
        let editor = makeEditor(glass, rig, image: nil)

        await editor.chooseCover()

        #expect(editor.coverMessage == nil && !editor.canSave)
    }

    @Test func startsFromTheStoredValuesWithUnknownsLeftBlank() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let loose = try #require(rig.library.visibleTracks.first { $0.title == "Loose Demo" })

        let editor = makeEditor(loose, rig)

        #expect(editor.title == "Loose Demo")
        #expect(editor.artist == "", "\"Unknown Artist\" is shown as a placeholder, not as text")
        #expect(editor.album == "")
        #expect(editor.albumArtist == UnknownTag.artist, "album artist is shown as stored")
        #expect(editor.year == "" && editor.trackNumber == "")
        #expect(editor.fileName == "03 - Loose Demo.wav")
        #expect(editor.fileSummary.hasPrefix("WAV"))
        #expect(!editor.canSave, "nothing has changed yet")
        #expect(editor.problem == nil)
    }

    @Test func savingNeedsAChangeAndValidInput() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let loose = try #require(rig.library.visibleTracks.first { $0.title == "Loose Demo" })
        let editor = makeEditor(loose, rig)

        editor.year = "20O4"
        #expect(editor.problem == .invalidYear)
        #expect(!editor.canSave)
        #expect(!editor.save())
        #expect(loose.year == nil)

        editor.year = "2004"
        editor.title = "   "
        #expect(editor.problem == .emptyTitle)
        #expect(!editor.canSave)

        editor.title = "Loose Demo"
        editor.artist = "New Artist"
        #expect(editor.problem == nil)
        #expect(editor.canSave)
        #expect(editor.save())
        #expect(loose.artist == "New Artist")
        #expect(loose.year == 2004)
        #expect(loose.albumArtist == UnknownTag.artist, "album artist stays put when only the artist changes")
    }

    @Test func clearingAnAlbumArtistMakesItFollowTheArtist() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = try #require(rig.library.visibleTracks.first { $0.title == "Glass Rooms" })
        let editor = makeEditor(glass, rig)

        editor.albumArtist = ""

        #expect(editor.problem == nil)
        #expect(editor.canSave == false, "it already equals the artist, so nothing changes")
        editor.artist = "Maren Volk & Friends"
        #expect(editor.save())
        #expect(glass.albumArtist == "Maren Volk & Friends")
    }
}
