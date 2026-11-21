import Foundation
import Testing
@testable import Spindle

/// A picker that returns whatever it was given, standing in for NSOpenPanel.
struct FakePicker: FilePicking {
    var files: [URL] = []
    var folders: [URL] = []
    var image: URL?
    func pickFiles() async -> [URL] { files }
    func pickFolders() async -> [URL] { folders }
    func pickImage() async -> URL? { image }
}

@MainActor
struct Rig {
    let harness: LibraryHarness
    let service: PlayerService
    let library: LibraryViewModel
    let playlists: PlaylistsViewModel
    let player: PlayerViewModel
    let toasts: ToastCenter
    let app: AppViewModel

    /// A library imported from `makeMusicFolder()`: 4 tracks, 3 albums (one of them "Unknown Album").
    static func make() async throws -> Rig {
        let harness = try LibraryHarness()
        await harness.importAndWait([try await harness.makeMusicFolder()])
        let service = PlayerService(defaults: harness.makeDefaults(), files: harness.files)
        service.volume = 0
        let toasts = ToastCenter()
        return Rig(
            harness: harness,
            service: service,
            library: LibraryViewModel(library: harness.library, player: service),
            playlists: PlaylistsViewModel(library: harness.library, toasts: toasts),
            player: PlayerViewModel(service: service, library: harness.library, artwork: harness.artwork),
            toasts: toasts,
            app: AppViewModel()
        )
    }
}

@MainActor
struct LibraryViewModelTests {
    @Test func summaryCountsAlbumsAndTracks() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        #expect(rig.library.summary.hasPrefix("3 albums \u{00B7} 4 tracks"))
        #expect(!rig.library.isLibraryEmpty)
    }

    @Test func albumsFilterSortsAlphabetically() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.library.filter = .albums

        #expect(rig.library.visibleAlbums.map(\.title) == ["Low Tide Hours", "Paper Lanterns", UnknownTag.album])
    }

    @Test func artistsFilterGroupsAlbumsByArtist() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.library.filter = .artists

        #expect(rig.library.visibleArtists.map(\.name) == ["Maren Volk", UnknownTag.artist, "The Quiet Arcade"].sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        })
        let maren = try #require(rig.library.visibleArtists.first { $0.name == "Maren Volk" })
        #expect(maren.trackCount == 2)
    }

    @Test func titleSortFlattensTheList() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.library.sort = .title

        #expect(rig.library.visibleTracks.map(\.title) == ["Glass Rooms", "Lantern Song", "Loose Demo", "Undertow"])
    }

    @Test func searchMatchesTitleArtistAndAlbumIgnoringCaseAndDiacritics() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.library.searchText = "VOLK"
        #expect(rig.library.visibleAlbums.map(\.title) == ["Low Tide Hours"])
        #expect(rig.library.visibleTracks.count == 2)

        rig.library.searchText = "lantern song"
        #expect(rig.library.visibleTracks.map(\.title) == ["Lantern Song"])
        #expect(rig.library.visibleAlbums.map(\.title) == ["Paper Lanterns"])

        rig.library.searchText = "paper"
        #expect(rig.library.visibleAlbums.map(\.title) == ["Paper Lanterns"])
        #expect(!rig.library.hasNoResults)

        rig.library.searchText = "zzzz"
        #expect(rig.library.hasNoResults)

        rig.library.clearSearch()
        #expect(rig.library.visibleAlbums.count == 3)
    }

    @Test func derivedDataFollowsLibraryChanges() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        #expect(rig.library.visibleTracks.count == 4)

        // Albums come from tags, not folders: only "Lantern Song" is tagged "Paper Lanterns".
        // "Loose Demo" sits in that folder but is untagged, so it belongs to "Unknown Album".
        rig.library.remove(rig.library.visibleTracks.filter { $0.album == "Paper Lanterns" })

        #expect(rig.library.visibleTracks.count == 3)
        #expect(rig.library.visibleAlbums.map(\.title).sorted() == ["Low Tide Hours", UnknownTag.album])
    }

    @Test func removingTheCurrentTrackStopsPlayback() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks
        rig.player.play(tracks[0], in: tracks, context: "My Music")
        #expect(rig.player.hasItem)

        rig.library.remove([tracks[0]])

        #expect(!rig.player.hasItem)
    }
}

@MainActor
struct PlaylistsViewModelTests {
    @Test func creatingAndAddingProducesFeedback() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks

        let playlist = rig.playlists.create(named: "Road Trip", adding: [tracks[0].id])
        #expect(rig.toasts.message == "Added to \u{201C}Road Trip\u{201D}")

        rig.playlists.add([tracks[0]], to: playlist)
        #expect(rig.toasts.message == "Already in \u{201C}Road Trip\u{201D}")

        rig.playlists.add([tracks[1]], to: playlist)
        #expect(rig.toasts.message == "Added to \u{201C}Road Trip\u{201D}")
        #expect(rig.playlists.summary(for: playlist.id)?.trackCount == 2)
    }

    @Test func summariesExposeCoversAndSortByName() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let withCovers = rig.library.visibleTracks.filter { $0.artworkKey != nil }
        rig.playlists.create(named: "Zeta", adding: withCovers.map(\.id))
        rig.playlists.create(named: "Alpha")

        rig.playlists.sort = .name

        #expect(rig.playlists.summaries.map(\.name) == ["Alpha", "Zeta"])
        let zeta = try #require(rig.playlists.summaries.last)
        #expect(zeta.artworkKeys.count == 2, "two distinct covers among the three tagged tracks")
        #expect(rig.playlists.summaries.first?.detail == "Empty")
        #expect(rig.playlists.headerSummary.hasPrefix("2 playlists"))
    }

    @Test func renameAndDelete() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let playlist = rig.playlists.create(named: "Old")

        rig.playlists.rename(playlist.id, to: "New")
        #expect(rig.playlists.summary(for: playlist.id)?.name == "New")

        rig.playlists.delete(playlist.id)
        #expect(rig.playlists.summary(for: playlist.id) == nil)
        #expect(rig.toasts.message == "Deleted \u{201C}New\u{201D}")
    }

    @Test func removingATrackKeepsTheRestInOrder() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks
        let playlist = rig.playlists.create(named: "Mix", adding: tracks.map(\.id))

        rig.playlists.remove([tracks[1]], from: playlist)

        #expect(rig.playlists.summary(for: playlist.id)?.tracks.map(\.id) == [tracks[0].id, tracks[2].id, tracks[3].id])
    }
}

@MainActor
struct PlayerViewModelTests {
    @Test func scrubbingOverridesPositionUntilReleased() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks
        rig.player.play(tracks[0], in: tracks, context: "My Music")
        let duration = rig.player.duration
        #expect(duration > 1)

        rig.player.beginScrub()
        rig.player.updateScrub(0.5)
        #expect(rig.player.progress == 0.5)
        #expect(rig.player.elapsedText == TimeFormat.clock(duration * 0.5))
        #expect(rig.player.remainingText == TimeFormat.remaining(duration * 0.5))

        rig.player.endScrub(at: 0.75)
        #expect(rig.player.scrubFraction == nil)
        let landed = await waitUntil { abs(rig.service.currentTime - duration * 0.75) < 0.3 }
        #expect(landed, "released scrub should seek the player to 75%")
        rig.service.stop()
    }

    @Test func labelsDescribeTheCurrentTrackAndContext() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let tracks = rig.library.visibleTracks.filter { $0.title == "Glass Rooms" }

        rig.player.play(tracks, context: "Late Night Drive")

        #expect(rig.player.contextLabel == "Playing from Late Night Drive")
        #expect(rig.player.subtitle == "Maren Volk \u{2014} Low Tide Hours")
        #expect(rig.player.currentTrack?.title == "Glass Rooms")
        rig.service.stop()
    }

    @Test func muteRestoresThePreviousVolume() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        rig.player.volume = 0.4

        rig.player.toggleMute()
        #expect(rig.player.isMuted)
        rig.player.toggleMute()

        #expect(abs(rig.player.volume - 0.4) < 0.001)
    }

    @Test func volumeIsClamped() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }

        rig.player.volume = 3
        #expect(rig.player.volume == 1)
        rig.player.volume = -1
        #expect(rig.player.volume == 0)
    }

    @Test func tintComesFromTheCoverColour() async throws {
        let rig = try await Rig.make()
        defer { rig.harness.cleanUp() }
        let glass = rig.library.visibleTracks.filter { $0.title == "Glass Rooms" } // cover: warm yellow/orange
        rig.player.play(glass, context: "My Music")

        await rig.player.refreshTint()

        let tint = try #require(rig.player.tint)
        #expect(tint.red > tint.blue, "a warm cover should tint warm, got \(tint)")
        rig.service.stop()
    }
}

@MainActor
struct AppViewModelTests {
    @Test func navigationHistoryWorksLikeABrowser() {
        let app = AppViewModel()
        #expect(app.route == .myMusic)
        #expect(!app.canGoBack && !app.canGoForward)

        app.navigate(to: .playlists)
        app.navigate(to: .album("a"))
        #expect(app.tab == .myMusic)

        app.goBack()
        #expect(app.route == .playlists)
        #expect(app.tab == .playlists)
        #expect(app.canGoForward)

        app.goForward()
        #expect(app.route == .album("a"))

        app.goBack()
        app.navigate(to: .artist("b"))
        #expect(!app.canGoForward, "navigating somewhere new clears forward history")

        let depth = app.canGoBack
        app.navigate(to: .artist("b"))
        #expect(app.canGoBack == depth, "navigating to the current page adds no history")
    }

    @Test func nowPlayingAndQueueToggles() {
        let app = AppViewModel()
        app.isQueueVisible = true
        app.presentNowPlaying()
        #expect(app.isNowPlayingPresented)

        app.dismissNowPlaying()
        #expect(!app.isNowPlayingPresented)
        #expect(!app.isQueueVisible)
    }
}

@MainActor
struct ImportViewModelTests {
    private func makeImporter(_ rig: Rig, picker: FakePicker) -> ImportViewModel {
        ImportViewModel(library: rig.harness.library, picker: picker, app: rig.app, toasts: rig.toasts)
    }

    @Test func choosingAFolderImportsItAndOpensTheDialog() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let folder = try await harness.makeMusicFolder()
        let app = AppViewModel()
        let importer = ImportViewModel(library: harness.library, picker: FakePicker(folders: [folder]), app: app, toasts: ToastCenter())

        await importer.chooseFolder()
        await harness.library.waitForImport()

        #expect(app.isAddMusicPresented)
        #expect(harness.library.tracks.count == 4)
        #expect(importer.resultText == "4 added")
        #expect(!importer.isImporting)
    }

    @Test func cancellingThePickerDoesNothing() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let app = AppViewModel()
        let importer = ImportViewModel(library: harness.library, picker: FakePicker(), app: app, toasts: ToastCenter())

        await importer.chooseFiles()

        #expect(!app.isAddMusicPresented)
        #expect(harness.library.importSession == nil)
    }

    @Test func dropsOfNonFileURLsAreRejected() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let importer = ImportViewModel(library: harness.library, picker: FakePicker(), app: AppViewModel(), toasts: ToastCenter())

        #expect(!importer.handleDrop([URL(string: "https://example.com/song.mp3")!]))
        #expect(!importer.handleDrop([]))
    }

    @Test func droppedFilesAreImportedAndResultTextReportsSkips() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let files = try harness.makePlainTracks(count: 2)
        let importer = ImportViewModel(library: harness.library, picker: FakePicker(), app: AppViewModel(), toasts: ToastCenter())

        #expect(importer.handleDrop(files))
        await harness.library.waitForImport()
        #expect(harness.library.tracks.count == 2)

        #expect(importer.handleDrop(files))
        await harness.library.waitForImport()
        #expect(importer.resultText == "0 added \u{00B7} 2 skipped")
    }

    @Test func closingAfterAFinishedImportClearsTheSession() async throws {
        let harness = try LibraryHarness()
        defer { harness.cleanUp() }
        let app = AppViewModel()
        let importer = ImportViewModel(library: harness.library, picker: FakePicker(), app: app, toasts: ToastCenter())
        _ = importer.handleDrop(try harness.makePlainTracks(count: 1))
        await harness.library.waitForImport()

        importer.close()

        #expect(!app.isAddMusicPresented)
        #expect(harness.library.importSession == nil)
    }
}

struct TimeFormatTests {
    @Test(arguments: [
        (0.0, "0:00"), (5.9, "0:05"), (134.0, "2:14"), (3599.0, "59:59"), (3725.0, "1:02:05"), (-4.0, "0:00"),
    ])
    func clock(seconds: Double, expected: String) {
        #expect(TimeFormat.clock(seconds) == expected)
    }

    @Test(arguments: [(113.0, "\u{2212}1:53"), (0.0, "\u{2212}0:00")])
    func remaining(seconds: Double, expected: String) {
        #expect(TimeFormat.remaining(seconds) == expected)
    }

    @Test(arguments: [(7440.0, "2 h 4 min"), (3480.0, "58 min"), (7200.0, "2 h"), (0.0, "0 min")])
    func summary(seconds: Double, expected: String) {
        #expect(TimeFormat.summary(seconds) == expected)
    }

    @Test func pluralisation() {
        #expect(TimeFormat.count(1, "track") == "1 track")
        #expect(TimeFormat.count(0, "track") == "0 tracks")
        #expect(TimeFormat.count(18, "album") == "18 albums")
    }
}
