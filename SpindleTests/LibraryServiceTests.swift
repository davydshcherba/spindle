import Foundation
import SwiftData
import Testing
@testable import Spindle

@MainActor
struct LibraryServiceTests {
    // MARK: Import

    @Test func importsFolderRecursivelyAndSkipsNonAudio() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let folder = try await harness.makeMusicFolder()

        await harness.importAndWait([folder])

        let titles = Set(harness.library.tracks.map(\.title))
        #expect(titles == ["Glass Rooms", "Undertow", "Lantern Song", "Loose Demo"])
        let session = try #require(harness.library.importSession)
        #expect(session.isFinished)
        #expect(session.addedCount == 4)
        #expect(session.failedCount == 0)
    }

    @Test func storesMetadataOnTracks() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])

        let glass = try #require(harness.library.tracks.first { $0.title == "Glass Rooms" })
        #expect(glass.artist == "Maren Volk")
        #expect(glass.album == "Low Tide Hours")
        #expect(glass.trackNumber == 1)
        #expect(glass.fileExtension == "m4a")
        #expect(glass.fileSize > 0)
        #expect(abs(glass.duration - 2) < 0.25)

        let loose = try #require(harness.library.tracks.first { $0.title == "Loose Demo" })
        #expect(loose.artist == UnknownTag.artist)
        #expect(loose.album == UnknownTag.album)
    }

    @Test func skipsDuplicatesOnReimport() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let folder = try await harness.makeMusicFolder()

        await harness.importAndWait([folder])
        await harness.importAndWait([folder], skipDuplicates: true)

        #expect(harness.library.tracks.count == 4)
        #expect(harness.library.importSession?.skippedCount == 4)
        #expect(harness.library.importSession?.addedCount == 0)
    }

    @Test func importsDuplicatesWhenAskedTo() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let folder = try await harness.makeMusicFolder()

        await harness.importAndWait([folder])
        await harness.importAndWait([folder], skipDuplicates: false)

        #expect(harness.library.tracks.count == 8)
    }

    @Test func unplayableFilesFailWithoutBlockingTheRest() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 2)
        let broken = harness.root.appending(path: "broken.mp3")
        try Data("this is not audio".utf8).write(to: broken)

        await harness.importAndWait(urls + [broken])

        #expect(harness.library.tracks.count == 2)
        #expect(harness.library.importSession?.failedCount == 1)
        #expect(harness.library.importSession?.addedCount == 2)
    }

    @Test func importingNothingPlayableFinishesCleanly() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let notes = harness.root.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: notes)

        await harness.importAndWait([notes])

        #expect(harness.library.tracks.isEmpty)
        #expect(harness.library.importSession?.isFinished == true)
        #expect(harness.library.importSession?.total == 0)
    }

    // MARK: The library's own copies & persistence

    @Test func importCopiesTheSongIntoTheLibraryAndLeavesTheOriginal() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(urls)

        let track = try #require(harness.library.tracks.first)
        let name = try #require(track.libraryFileName)
        #expect(name.hasSuffix(".wav"))
        #expect(harness.files.exists(name))
        #expect(try Data(contentsOf: harness.files.url(for: name)) == Data(contentsOf: urls[0]))
        #expect(FileManager.default.fileExists(atPath: urls[0].path), "the original must stay where it was")
        #expect(track.bookmarkData.isEmpty, "new songs need no pointer to the original")
    }

    @Test func theLibraryKeepsTheSongWhenTheOriginalIsDeleted() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(urls)
        try FileManager.default.removeItem(at: urls[0])

        let name = try #require(harness.library.tracks.first?.libraryFileName)
        #expect(harness.files.exists(name))
    }

    @Test func removingASongDeletesItsCopyButNotTheOriginal() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 2)
        await harness.importAndWait(urls)
        let removed = try #require(harness.library.tracks.first { $0.title == "Track 1" })
        let kept = try #require(harness.library.tracks.first { $0.title == "Track 2" })
        let removedName = try #require(removed.libraryFileName)
        let keptName = try #require(kept.libraryFileName)

        harness.library.remove([removed])

        #expect(!harness.files.exists(removedName))
        #expect(harness.files.exists(keptName))
        #expect(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }, "originals are never deleted")
    }

    @Test func aSkippedDuplicateLeavesNoStrayCopy() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        // The same recording kept in another folder: different path, same title and length.
        let otherFolder = harness.root.appending(path: "elsewhere", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
        let twin = otherFolder.appending(path: urls[0].lastPathComponent)
        try FileManager.default.copyItem(at: urls[0], to: twin)

        await harness.importAndWait(urls)
        await harness.importAndWait([twin])

        #expect(harness.library.tracks.count == 1)
        let stored = try FileManager.default.contentsOfDirectory(atPath: harness.files.directory.path)
        #expect(stored.count == 1, "only one copy of the recording should be kept")
    }

    // MARK: Songs from before Spindle kept its own copies

    private func insertLegacyTrack(in harness: LibraryHarness, original: URL) throws {
        let legacy = Track(
            title: "Track 1", artist: "Someone", albumArtist: "Someone", album: "Old Album",
            duration: 2, fileSize: 1, fileExtension: "wav", filePath: original.path,
            libraryFileName: nil, bookmarkData: try SecurityScopedBookmark.make(for: original)
        )
        harness.container.mainContext.insert(legacy)
        try harness.container.mainContext.save()
        harness.library.reload()
    }

    @Test func olderSongsAreCopiedIntoTheLibrary() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        try insertLegacyTrack(in: harness, original: urls[0])

        await harness.library.migrateLegacyTracks()

        let track = try #require(harness.library.tracks.first)
        let name = try #require(track.libraryFileName)
        #expect(harness.files.exists(name))
        #expect(track.bookmarkData.isEmpty)
        #expect(FileManager.default.fileExists(atPath: urls[0].path), "the original stays where it was")
    }

    @Test func anOlderSongWhoseOriginalIsGoneIsLeftForALaterTry() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        try insertLegacyTrack(in: harness, original: urls[0])
        try FileManager.default.removeItem(at: urls[0])

        await harness.library.migrateLegacyTracks()

        let track = try #require(harness.library.tracks.first)
        #expect(track.libraryFileName == nil)
        #expect(!track.bookmarkData.isEmpty, "the pointer is kept so a later launch can try again")
    }

    @Test func addingTheSongAgainRepairsAnOlderSongWhoseOriginalWasDeleted() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        try insertLegacyTrack(in: harness, original: urls[0])
        try FileManager.default.removeItem(at: urls[0])
        await harness.library.migrateLegacyTracks()
        let before = try #require(harness.library.tracks.first)
        #expect(before.libraryFileName == nil, "nothing to copy: the original is gone")
        let playlist = harness.library.createPlaylist(named: "Mine", adding: [before.id])

        // The file comes back (restored from a backup) and is added again.
        let restored = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(restored)

        #expect(harness.library.tracks.count == 1, "the song is repaired, not added a second time")
        let after = try #require(harness.library.tracks.first)
        #expect(after.id == before.id)
        let name = try #require(after.libraryFileName)
        #expect(harness.files.exists(name))
        #expect(after.bookmarkData.isEmpty)
        #expect(after.album == "Old Album", "what the library knew about the song is kept")
        #expect(playlist.trackIDs == [before.id], "and so is its place in the playlist")
    }

    @Test func addingTheSongAgainRepairsASongWhoseCopyWasLost() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(urls)
        let before = try #require(harness.library.tracks.first)
        let lostName = try #require(before.libraryFileName)
        harness.files.remove(lostName)
        #expect(!harness.files.exists(lostName))

        await harness.importAndWait(urls)

        #expect(harness.library.tracks.count == 1)
        let after = try #require(harness.library.tracks.first)
        #expect(after.id == before.id)
        let name = try #require(after.libraryFileName)
        #expect(harness.files.exists(name), "the song plays again")
    }

    @Test func aSongThatStillPlaysIsStillSkippedAsADuplicate() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(urls)
        let name = try #require(harness.library.tracks.first?.libraryFileName)

        await harness.importAndWait(urls)

        #expect(harness.library.tracks.count == 1)
        #expect(harness.library.tracks.first?.libraryFileName == name, "the working copy is left alone")
        #expect(try FileManager.default.contentsOfDirectory(atPath: harness.files.directory.path).count == 1)
    }

    @Test func libraryLoadsAgainOnNextLaunchWithoutReimporting() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])
        let playlist = harness.library.createPlaylist(named: "Favourites")
        harness.library.add(trackIDs: harness.library.tracks.map(\.id), to: playlist)

        // A fresh service over the same store behaves like a relaunch.
        let relaunched = LibraryService(modelContext: ModelContext(harness.container), artwork: harness.artwork, files: harness.files)

        #expect(relaunched.tracks.count == 4)
        #expect(relaunched.playlists.map(\.name) == ["Favourites"])
        let track = try #require(relaunched.tracks.first)
        let name = try #require(track.libraryFileName)
        #expect(harness.files.exists(name))
    }

    // MARK: Artwork

    @Test func tracksOfOneAlbumShareStoredArtwork() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])

        let glass = try #require(harness.library.tracks.first { $0.title == "Glass Rooms" })
        let undertow = try #require(harness.library.tracks.first { $0.title == "Undertow" })
        let lantern = try #require(harness.library.tracks.first { $0.title == "Lantern Song" })

        let key = try #require(glass.artworkKey)
        #expect(undertow.artworkKey == key)
        #expect(lantern.artworkKey != nil)
        #expect(lantern.artworkKey != key)
        #expect(harness.artwork.image(forKey: key, maxPixelSize: 128) != nil)
    }

    // MARK: Albums

    @Test func groupsTracksIntoAlbumsInTrackOrder() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])

        let albums = Album.group(harness.library.tracks)
        let lowTide = try #require(albums.first { $0.title == "Low Tide Hours" })

        #expect(albums.count == 3)
        #expect(lowTide.tracks.map(\.title) == ["Glass Rooms", "Undertow"])
        #expect(lowTide.artworkKey != nil)
    }

    // MARK: Playlists

    @Test func playlistLifecycle() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait(try harness.makePlainTracks(count: 3))
        let library = harness.library
        let ids = library.tracks.map(\.id)

        let playlist = library.createPlaylist(named: "  Late Night  ")
        #expect(playlist.name == "Late Night")

        #expect(library.add(trackIDs: [ids[0], ids[1]], to: playlist) == 2)
        #expect(library.add(trackIDs: [ids[1], ids[2]], to: playlist) == 1, "tracks already in the playlist are not added twice")
        #expect(playlist.trackIDs == [ids[0], ids[1], ids[2]])

        library.remove(trackIDs: [ids[1]], from: playlist)
        #expect(playlist.trackIDs == [ids[0], ids[2]])
        #expect(library.tracks(in: playlist).map(\.id) == [ids[0], ids[2]])

        library.rename(playlist, to: "Early Morning")
        #expect(library.playlists.first?.name == "Early Morning")

        library.delete(playlist)
        #expect(library.playlists.isEmpty)
        #expect(library.tracks.count == 3, "deleting a playlist never deletes tracks")
    }

    @Test func newPlaylistsGetUniqueNames() throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }

        let names = (0..<3).map { _ in harness.library.createPlaylist(named: "").name }

        #expect(names == ["New Playlist", "New Playlist 2", "New Playlist 3"])
    }

    @Test func removingATrackFromTheLibraryRemovesItFromPlaylists() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait(try harness.makePlainTracks(count: 2))
        let library = harness.library
        let playlist = library.createPlaylist(named: "Mix", adding: library.tracks.map(\.id))
        let doomed = try #require(library.tracks.first)

        library.remove([doomed])

        #expect(library.tracks.count == 1)
        #expect(playlist.trackIDs.count == 1)
        #expect(!playlist.trackIDs.contains(doomed.id))
    }
}
