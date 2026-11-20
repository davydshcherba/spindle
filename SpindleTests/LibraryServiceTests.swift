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

    // MARK: Bookmarks & persistence

    @Test func savesBookmarksThatResolveToTheOriginalFile() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let urls = try harness.makePlainTracks(count: 1)
        await harness.importAndWait(urls)

        let track = try #require(harness.library.tracks.first)
        let resolved = try SecurityScopedBookmark.resolve(track.bookmarkData)

        #expect(resolved.url.resolvingSymlinksInPath().path == urls[0].resolvingSymlinksInPath().path)
        #expect(!resolved.isStale)
    }

    @Test func libraryLoadsAgainOnNextLaunchWithoutReimporting() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        await harness.importAndWait([try await harness.makeMusicFolder()])
        let playlist = harness.library.createPlaylist(named: "Favourites")
        harness.library.add(trackIDs: harness.library.tracks.map(\.id), to: playlist)

        // A fresh service over the same store behaves like a relaunch.
        let relaunched = LibraryService(modelContext: ModelContext(harness.container), artwork: harness.artwork)

        #expect(relaunched.tracks.count == 4)
        #expect(relaunched.playlists.map(\.name) == ["Favourites"])
        let track = try #require(relaunched.tracks.first)
        let resolved = try SecurityScopedBookmark.resolve(track.bookmarkData)
        #expect(FileManager.default.fileExists(atPath: resolved.url.path))
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
