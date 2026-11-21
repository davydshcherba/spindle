import Foundation
import MediaPlayer
import Testing
@testable import Spindle

@MainActor
struct PlayerServiceTests {
    private struct Setup {
        let harness: LibraryHarness
        let player: PlayerService
        let items: [PlayerItem]
        let urls: [URL]
    }

    /// Imports `count` plain tracks ("Track 1"…) and returns a silent player for them.
    private func makeSetup(count: Int = 3, seconds: Double = 2) async throws -> Setup {
        let harness = try LibraryHarness()
        let urls = try harness.makePlainTracks(count: count, seconds: seconds)
        await harness.importAndWait(urls)
        let items = harness.library.tracks.sorted { $0.title < $1.title }.map(\.playerItem)
        let player = PlayerService(defaults: harness.makeDefaults(), files: harness.files)
        player.volume = 0 // tests must never make noise
        return Setup(harness: harness, player: player, items: items, urls: urls)
    }

    // MARK: Playing a track

    @Test func importedTrackActuallyPlays() async throws {
        let setup = try await makeSetup()
        defer { setup.harness.cleanUp() }
        let player = setup.player

        player.play(setup.items, startIndex: 0, context: "My Music")

        #expect(player.isPlaying)
        #expect(player.currentItem?.title == "Track 1")
        let advanced = await waitUntil { player.currentTime > 0.5 }
        #expect(advanced, "playback position should advance while playing (got \(player.currentTime)s)")
        #expect(player.errorMessage == nil)

        player.pause()
        #expect(!player.isPlaying)
        let pausedAt = player.currentTime
        try await Task.sleep(for: .milliseconds(500))
        #expect(abs(player.currentTime - pausedAt) < 0.05, "position must not move while paused")

        player.play()
        #expect(player.isPlaying)
        let resumed = await waitUntil { player.currentTime > pausedAt + 0.3 }
        #expect(resumed)
        player.stop()
    }

    @Test func seekMovesThePlaybackPosition() async throws {
        let setup = try await makeSetup(seconds: 4)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, context: "My Music")
        _ = await waitUntil { player.currentTime > 0.2 }

        player.seek(to: 3)

        let landed = await waitUntil { player.currentTime >= 3 && player.currentTime < 3.6 }
        #expect(landed, "expected ~3s, got \(player.currentTime)s")
        player.stop()
    }

    // MARK: Queue navigation

    @Test func nextAndPreviousWalkTheQueue() async throws {
        let setup = try await makeSetup()
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, context: "My Music")

        player.next()
        #expect(player.currentItem?.title == "Track 2")
        player.next()
        #expect(player.currentItem?.title == "Track 3")

        player.previous() // just started, so this goes back instead of restarting
        #expect(player.currentItem?.title == "Track 2")
        player.stop()
    }

    @Test func previousRestartsATrackThatHasBeenPlayingForAWhile() async throws {
        let setup = try await makeSetup(seconds: 6)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, startIndex: 1, context: "My Music")
        player.seek(to: 4)
        _ = await waitUntil { player.currentTime >= 4 }

        player.previous()

        #expect(player.currentItem?.title == "Track 2")
        let restarted = await waitUntil { player.currentTime < 1 }
        #expect(restarted)
        player.stop()
    }

    @Test func nextAtTheEndStopsUnlessRepeatAll() async throws {
        let setup = try await makeSetup(count: 2)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, startIndex: 1, context: "My Music")

        player.next()
        #expect(!player.isPlaying, "repeat off: the queue ends")
        #expect(player.currentItem?.title == "Track 2")

        player.repeatMode = .all
        player.play()
        player.next()
        #expect(player.currentItem?.title == "Track 1", "repeat all wraps around")
        #expect(player.isPlaying)
        player.stop()
    }

    @Test func repeatCyclesOffAllOne() {
        #expect(RepeatMode.off.next == .all)
        #expect(RepeatMode.all.next == .one)
        #expect(RepeatMode.one.next == .off)
    }

    @Test func finishingATrackAdvancesAutomatically() async throws {
        let setup = try await makeSetup(count: 2, seconds: 1)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, context: "My Music")

        let advanced = await waitUntil(timeout: .seconds(8)) { player.currentItem?.title == "Track 2" }

        #expect(advanced, "should move on to Track 2 when Track 1 ends")
        #expect(player.isPlaying)
        player.stop()
    }

    @Test func repeatOneLoopsTheSameTrack() async throws {
        let setup = try await makeSetup(count: 2, seconds: 1)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.repeatMode = .one
        player.play(setup.items, context: "My Music")
        player.seek(to: 0.6)

        try await Task.sleep(for: .milliseconds(1800))

        #expect(player.currentItem?.title == "Track 1")
        #expect(player.isPlaying)
        player.stop()
    }

    // MARK: Shuffle

    @Test func shuffleKeepsCurrentTrackFirstAndRestoresOrderWhenTurnedOff() async throws {
        let setup = try await makeSetup(count: 6)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, startIndex: 2, context: "My Music")

        player.toggleShuffle()
        #expect(player.isShuffled)
        #expect(player.currentIndex == 0)
        #expect(player.currentItem?.title == "Track 3")
        #expect(Set(player.queue.map(\.item.id)) == Set(setup.items.map(\.id)), "shuffle must not lose or duplicate tracks")

        player.toggleShuffle()
        #expect(!player.isShuffled)
        #expect(player.queue.map(\.item.title) == setup.items.map(\.title))
        #expect(player.currentItem?.title == "Track 3")
        #expect(player.currentIndex == 2)
        player.stop()
    }

    @Test func playingWithShuffleForcedStartsOnTheChosenTrack() async throws {
        let setup = try await makeSetup(count: 5)
        defer { setup.harness.cleanUp() }
        let player = setup.player

        player.play(setup.items, startIndex: 3, context: "Mix", shuffled: true)

        #expect(player.isShuffled)
        #expect(player.currentItem?.title == "Track 4")
        #expect(player.queue.count == 5)
        player.stop()
    }

    // MARK: Queue editing

    @Test func playNextAndAddToQueueReorderUpcomingTracks() async throws {
        let setup = try await makeSetup(count: 4)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(Array(setup.items[0..<2]), context: "My Music")

        player.addToQueue([setup.items[3]])
        player.playNext([setup.items[2]])

        #expect(player.upNext.map(\.item.title) == ["Track 3", "Track 2", "Track 4"])

        let removed = try #require(player.upNext.first { $0.item.title == "Track 2" })
        player.removeFromQueue(removed.id)
        #expect(player.upNext.map(\.item.title) == ["Track 3", "Track 4"])

        let target = try #require(player.upNext.last)
        player.jump(to: target.id)
        #expect(player.currentItem?.title == "Track 4")
        player.stop()
    }

    // MARK: Failure handling

    @Test func missingFileIsReportedAndSkipped() async throws {
        let setup = try await makeSetup(count: 3)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        let track = try #require(setup.harness.library.tracks.first { $0.title == "Track 1" })
        setup.harness.files.remove(try #require(track.libraryFileName)) // Spindle's own copy of "Track 1"

        player.play(setup.items, startIndex: 0, context: "My Music")

        #expect(player.errorMessage?.contains("Track 1") == true)
        #expect(player.currentItem?.title == "Track 2", "should skip to the next playable track")
        #expect(player.isPlaying)
        player.stop()
    }

    @Test func playsFromTheLibraryAfterTheOriginalIsDeleted() async throws {
        let setup = try await makeSetup(count: 2)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        for url in setup.urls { try FileManager.default.removeItem(at: url) }

        player.play(setup.items, startIndex: 0, context: "My Music")

        #expect(player.isPlaying)
        #expect(player.currentItem?.title == "Track 1")
        #expect(player.errorMessage == nil)
        let advanced = await waitUntil { player.currentTime > 0.5 }
        #expect(advanced, "the library's copy should play even though the original is gone")
        player.stop()
    }

    @Test func removingTheCurrentTrackStopsPlayback() async throws {
        let setup = try await makeSetup(count: 3)
        defer { setup.harness.cleanUp() }
        let player = setup.player
        player.play(setup.items, context: "My Music")

        player.removeItems(withIDs: [setup.items[0].id])

        #expect(player.currentItem == nil)
        #expect(!player.isPlaying)
    }

    // MARK: Now Playing

    @Test func nowPlayingInfoFollowsThePlayer() async throws {
        let setup = try await makeSetup()
        defer { setup.harness.cleanUp() }
        let player = setup.player
        let nowPlaying = NowPlayingService(player: player, artwork: setup.harness.artwork)
        withExtendedLifetime(nowPlaying) {
            player.play(setup.items, context: "My Music")

            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            #expect(info?[MPMediaItemPropertyTitle] as? String == "Track 1")
            #expect(info?[MPMediaItemPropertyAlbumTitle] as? String == UnknownTag.album)
            #expect(info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
            #expect(MPNowPlayingInfoCenter.default().playbackState == .playing)

            player.pause()
            #expect(MPNowPlayingInfoCenter.default().playbackState == .paused)
            #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0)

            player.next()
            #expect(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "Track 2")

            let commands = MPRemoteCommandCenter.shared()
            #expect(commands.playCommand.isEnabled)
            #expect(commands.nextTrackCommand.isEnabled)
            #expect(commands.previousTrackCommand.isEnabled)
            #expect(commands.changePlaybackPositionCommand.isEnabled)
            player.stop()
        }
    }
}
