import Foundation
import SwiftData
import Testing
@testable import Spindle

struct AlbumEditValidationTests {
    private func validate(
        title: String = "Album", artist: String = "Artist", year: String = "",
        original: Int? = nil, cover: Change<String?> = .keep
    ) -> Result<AlbumEdit, AlbumEdit.Problem> {
        AlbumEdit.validated(title: title, artist: artist, year: year, originalYear: original, cover: cover)
    }

    @Test func emptyNameIsRejected() {
        #expect(validate(title: "  ") == .failure(.emptyTitle))
    }

    @Test func blankAlbumArtistBecomesUnknown() throws {
        #expect(try validate(artist: " ").get().artist == UnknownTag.artist)
    }

    @Test func yearOnlyChangesWhenItDiffers() throws {
        #expect(try validate(year: "2020", original: 2020).get().year == .keep)
        #expect(try validate(year: "2021", original: 2020).get().year == .set(2021))
        #expect(try validate(year: "", original: 2020).get().year == .set(nil), "clearing the field clears the year")
        #expect(try validate(year: "", original: nil).get().year == .keep)
    }

    @Test(arguments: ["24", "20x4", "99999", "-1"])
    func rejectsBadYears(text: String) {
        #expect(validate(year: text) == .failure(.invalidYear))
    }
}

@MainActor
struct AlbumEditingTests {
    private func album(_ title: String, in rig: Rig) throws -> Album {
        try #require(rig.library.visibleAlbums.first { $0.title == title })
    }

    @Test func renamingAnAlbumRenamesEverySongInIt() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let original = try album("Low Tide Hours", in: rig)

        let newID = rig.library.apply(
            AlbumEdit(title: "Low Tide (Deluxe)", artist: "Maren Volk", year: .set(2025), cover: .keep),
            to: original
        )

        #expect(newID == Album.key(artist: "Maren Volk", title: "Low Tide (Deluxe)"))
        let renamed = try #require(rig.library.album(withID: newID))
        #expect(renamed.tracks.map(\.title) == ["Glass Rooms", "Undertow"])
        #expect(renamed.year == 2025)
        #expect(rig.library.album(withID: original.id) == nil)
    }

    @Test func albumsWithTheSameNameAndArtistMerge() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        #expect(rig.library.visibleAlbums.count == 3)

        rig.library.apply(
            AlbumEdit(title: "Low Tide Hours", artist: "Maren Volk", year: .keep, cover: .keep),
            to: try album("Paper Lanterns", in: rig)
        )

        #expect(rig.library.visibleAlbums.count == 2)
        #expect(try album("Low Tide Hours", in: rig).tracks.count == 3)
    }

    @Test func aCoverCanBeSetAndRemovedForTheWholeAlbum() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let original = try album("Low Tide Hours", in: rig)

        rig.library.apply(AlbumEdit(title: original.title, artist: original.artist, year: .keep, cover: .set("my-cover")), to: original)
        let withCover = try album("Low Tide Hours", in: rig)
        #expect(withCover.artworkKey == "my-cover")
        #expect(withCover.tracks.allSatisfy { $0.artworkKey == "my-cover" })

        rig.library.apply(AlbumEdit(title: original.title, artist: original.artist, year: .keep, cover: .set(nil)), to: withCover)
        #expect(try album("Low Tide Hours", in: rig).artworkKey == nil)
    }

    @Test func queuedSongsFollowAnAlbumEdit() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let original = try album("Low Tide Hours", in: rig)
        rig.player.play(original.tracks, context: "My Music")

        rig.library.apply(AlbumEdit(title: "Renamed Album", artist: "Maren Volk", year: .keep, cover: .keep), to: original)

        #expect(rig.player.currentItem?.album == "Renamed Album")
        #expect(rig.service.queue.allSatisfy { $0.item.album == "Renamed Album" })
        rig.service.stop()
    }

    @Test func putAllSongsInOneAlbumKeepsArtists() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.library.putAllSongsInOneAlbum()

        #expect(rig.library.visibleAlbums.count == 1)
        let all = try #require(rig.library.visibleAlbums.first)
        #expect(all.title == LibraryDefaults.songsAlbum)
        #expect(all.artist == LibraryDefaults.variousArtists)
        #expect(all.tracks.count == 4)
        #expect(Set(all.tracks.map(\.artist)) == ["Maren Volk", "The Quiet Arcade", UnknownTag.artist])
    }

    @Test func importCanPutEverythingInOneAlbum() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let folder = try await harness.makeMusicFolder()

        harness.library.importItems([folder], singleAlbum: LibraryDefaults.songsAlbum)
        await harness.library.waitForImport()

        #expect(harness.library.tracks.count == 4)
        #expect(Set(harness.library.tracks.map(\.album)) == [LibraryDefaults.songsAlbum])
        #expect(Set(harness.library.tracks.map(\.albumArtist)) == [LibraryDefaults.variousArtists])
        #expect(Set(harness.library.tracks.map(\.artist)).count == 3, "artists are not overwritten")
    }

    @Test func theOneAlbumChoiceIsRememberedAndUsedByTheImporter() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let defaults = harness.makeDefaults()
        let make = { ImportViewModel(library: harness.library, picker: FakePicker(), app: AppViewModel(), toasts: ToastCenter(), defaults: defaults) }

        let first = make()
        #expect(!first.putInOneAlbum)
        first.putInOneAlbum = true

        let second = make()
        #expect(second.putInOneAlbum, "the choice survives a relaunch")
        #expect(second.handleDrop(try harness.makePlainTracks(count: 2)))
        await harness.library.waitForImport()
        #expect(Set(harness.library.tracks.map(\.album)) == [LibraryDefaults.songsAlbum])
    }
}

@MainActor
struct AlbumEditorViewModelTests {
    private func makeEditor(_ rig: Rig, album title: String, image: URL? = nil) throws -> AlbumEditorViewModel {
        let album = try #require(rig.library.visibleAlbums.first { $0.title == title })
        let covers = CoverImporter(picker: FakePicker(image: image), artwork: rig.harness.artwork)
        return AlbumEditorViewModel(album: album, library: rig.library, covers: covers)
    }

    private func writeImage(in rig: Rig) throws -> URL {
        let url = rig.harness.root.appending(path: "cover.jpg")
        try Fixtures.coverJPEG(red: 0.2, green: 0.6, blue: 0.9).write(to: url)
        return url
    }

    @Test func startsFromTheAlbumAndNeedsAChangeToSave() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        let editor = try makeEditor(rig, album: "Low Tide Hours")

        #expect(editor.title == "Low Tide Hours" && editor.artist == "Maren Volk")
        #expect(editor.songCount == 2)
        #expect(editor.hasCover, "the album already has the embedded cover")
        #expect(!editor.canSave)
        editor.title = "Low Tide"
        #expect(editor.canSave)
        editor.title = " "
        #expect(editor.problem == .emptyTitle)
        #expect(!editor.canSave)
    }

    @Test func warnsWhenTheNewNameMergesWithAnotherAlbum() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = try makeEditor(rig, album: "Paper Lanterns")
        #expect(editor.mergeNotice == nil)

        editor.title = "Low Tide Hours"
        editor.artist = "Maren Volk"

        #expect(editor.mergeNotice?.contains("already exists") == true)
        let newID = try #require(editor.save())
        #expect(newID == Album.key(artist: "Maren Volk", title: "Low Tide Hours"))
        #expect(rig.library.visibleAlbums.count == 2)
    }

    @Test func choosingAPictureSetsTheCoverForAllSongs() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = try makeEditor(rig, album: "Low Tide Hours", image: try writeImage(in: rig))
        let before = editor.previewKey

        await editor.chooseCover()

        let chosen = try #require(editor.previewKey)
        #expect(chosen != before)
        #expect(rig.harness.artwork.image(forKey: chosen, maxPixelSize: 128) != nil, "the picture was stored")
        #expect(editor.canSave)
        let newID = try #require(editor.save())
        #expect(try #require(rig.library.album(withID: newID)).tracks.allSatisfy { $0.artworkKey == chosen })
    }

    @Test func removingTheCoverClearsIt() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let editor = try makeEditor(rig, album: "Low Tide Hours")

        editor.removeCover()

        #expect(!editor.hasCover)
        #expect(editor.canSave)
        let newID = try #require(editor.save())
        #expect(try #require(rig.library.album(withID: newID)).artworkKey == nil)
    }

    @Test func aFileThatIsNotAPictureIsReported() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let notAPicture = rig.harness.root.appending(path: "fake.png")
        try Data("definitely not a png".utf8).write(to: notAPicture)
        let editor = try makeEditor(rig, album: "Low Tide Hours", image: notAPicture)

        await editor.chooseCover()

        #expect(editor.coverMessage?.contains("picture") == true)
        #expect(!editor.canSave)
    }
}

@MainActor
struct PlaylistCoverTests {
    private func makePlaylist(_ rig: Rig, name: String = "Mix") -> Playlist {
        rig.playlists.create(named: name, adding: rig.library.visibleTracks.map(\.id))
    }

    @Test func aChosenPictureReplacesTheMosaicUntilRemoved() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let playlist = makePlaylist(rig)
        let automatic = try #require(rig.playlists.summary(for: playlist.id)).artworkKeys
        #expect(automatic.count == 2)

        rig.playlists.update(playlist.id, name: "Mix", cover: .set("my-cover"))
        let custom = try #require(rig.playlists.summary(for: playlist.id))
        #expect(custom.artworkKeys == ["my-cover"])
        #expect(custom.coverKey == "my-cover")
        #expect(custom.autoArtworkKeys == automatic)

        rig.playlists.update(playlist.id, name: "Mix", cover: .set(nil))
        let reverted = try #require(rig.playlists.summary(for: playlist.id))
        #expect(reverted.coverKey == nil)
        #expect(reverted.artworkKeys == automatic)
    }

    @Test func updatingNameAndCoverTogetherKeepsTheOtherWhenAsked() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let playlist = makePlaylist(rig)
        rig.playlists.update(playlist.id, name: "Mix", cover: .set("my-cover"))

        rig.playlists.update(playlist.id, name: "Road Trip", cover: .keep)
        #expect(rig.playlists.summary(for: playlist.id)?.name == "Road Trip")
        #expect(rig.playlists.summary(for: playlist.id)?.coverKey == "my-cover", "keep leaves the picture alone")

        rig.playlists.update(playlist.id, name: "   ", cover: .keep)
        #expect(rig.playlists.summary(for: playlist.id)?.name == "Road Trip", "a blank name keeps the old one")
    }

    @Test func theCoverSurvivesARelaunch() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let playlist = makePlaylist(rig)

        rig.playlists.update(playlist.id, name: "Mix", cover: .set("my-cover"))

        let relaunched = LibraryService(modelContext: ModelContext(rig.harness.container), artwork: rig.harness.artwork)
        #expect(relaunched.playlists.first { $0.id == playlist.id }?.coverKey == "my-cover")
    }

    @Test func editorFollowsTheSameRules() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let playlist = makePlaylist(rig)
        let image = rig.harness.root.appending(path: "cover.jpg")
        try Fixtures.coverJPEG(red: 0.9, green: 0.3, blue: 0.3).write(to: image)
        let covers = CoverImporter(picker: FakePicker(image: image), artwork: rig.harness.artwork)
        let automatic = try #require(rig.playlists.summary(for: playlist.id)).artworkKeys

        let editor = PlaylistEditorViewModel(mode: .edit(playlist.id), playlists: rig.playlists, covers: covers)
        #expect(editor.name == "Mix" && editor.title == "Edit playlist")
        #expect(!editor.canSave && !editor.hasCustomCover)

        editor.name = "  "
        #expect(!editor.canSave, "a playlist needs a name")

        editor.name = "Road Trip"
        await editor.chooseCover()
        #expect(editor.hasCustomCover)
        #expect(editor.previewKeys.count == 1 && editor.previewKeys != automatic)

        editor.useAutomaticCover()
        #expect(!editor.hasCustomCover)
        #expect(editor.previewKeys == automatic)

        await editor.chooseCover()
        #expect(editor.save() == nil, "editing never navigates")
        let saved = try #require(rig.playlists.summary(for: playlist.id))
        #expect(saved.name == "Road Trip")
        #expect(saved.coverKey != nil)
    }

    @Test func creatingFromThePlaylistsPageReturnsTheNewPlaylistToOpen() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let covers = CoverImporter(picker: FakePicker(), artwork: rig.harness.artwork)

        let empty = PlaylistEditorViewModel(mode: .create(adding: []), playlists: rig.playlists, covers: covers)
        #expect(empty.isCreating && empty.canSave && empty.title == "New playlist")
        let createdID = try #require(empty.save())
        #expect(rig.playlists.summary(for: createdID)?.name == "New Playlist")

        let withTrack = PlaylistEditorViewModel(
            mode: .create(adding: [rig.library.visibleTracks[0].id]), playlists: rig.playlists, covers: covers
        )
        withTrack.name = "Favourites"
        #expect(withTrack.save() == nil, "created from a song's menu: stay where you are")
    }
}

@MainActor
struct CoverImporterTests {
    @Test func reportsCancelledNotAnImageAndChosen() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }

        let cancelled = CoverImporter(picker: FakePicker(), artwork: harness.artwork)
        #expect(await cancelled.choose() == .cancelled)

        let garbage = harness.root.appending(path: "garbage.png")
        try Data("nope".utf8).write(to: garbage)
        let notAnImage = CoverImporter(picker: FakePicker(image: garbage), artwork: harness.artwork)
        #expect(await notAnImage.choose() == .notAnImage)

        let picture = harness.root.appending(path: "picture.jpg")
        try Fixtures.coverJPEG(red: 0.1, green: 0.8, blue: 0.4).write(to: picture)
        let chosen = CoverImporter(picker: FakePicker(image: picture), artwork: harness.artwork)
        guard case .chosen(let key) = await chosen.choose() else {
            Issue.record("expected a chosen cover")
            return
        }
        #expect(harness.artwork.image(forKey: key, maxPixelSize: 128) != nil)
    }
}
