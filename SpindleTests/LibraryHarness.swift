import Foundation
import SwiftData
@testable import Spindle

/// An isolated, in-memory library plus a scratch folder for fixture files.
@MainActor
final class LibraryHarness {
    let container: ModelContainer
    let library: LibraryService
    let artwork: ArtworkStore
    let root: URL
    private var defaultsSuites: [String] = []

    init() throws {
        container = try ModelContainer(
            for: Track.self, Playlist.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        root = try Fixtures.makeScratchDirectory()
        artwork = ArtworkStore(directory: root.appending(path: "artwork", directoryHint: .isDirectory))
        library = LibraryService(modelContext: container.mainContext, artwork: artwork)
    }

    /// A throwaway `UserDefaults` for a `PlayerService`; removed again in `cleanUp()`.
    func makeDefaults() -> UserDefaults {
        let name = "SpindleTests-\(UUID().uuidString)"
        defaultsSuites.append(name)
        return UserDefaults(suiteName: name)!
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        for suite in defaultsSuites { UserDefaults.standard.removePersistentDomain(forName: suite) }
        defaultsSuites.removeAll()
    }

    /// Imports and waits for completion.
    func importAndWait(_ urls: [URL], skipDuplicates: Bool = true) async {
        library.importItems(urls, skipDuplicates: skipDuplicates)
        await library.waitForImport()
    }

    /// A folder with mixed formats, nested folders, a hidden file and a non-audio file:
    ///
    ///     music/Low Tide Hours/01 - Glass Rooms.m4a   (tagged, cover A)
    ///     music/Low Tide Hours/02 - Undertow.mp3      (tagged, cover A)
    ///     music/Paper Lanterns/Lantern Song.flac      (tagged, cover B)
    ///     music/Paper Lanterns/03 - Loose Demo.wav    (untagged)
    ///     music/Paper Lanterns/cover.txt              (ignored)
    ///     music/.hidden.wav                           (ignored)
    func makeMusicFolder() async throws -> URL {
        let music = root.appending(path: "music", directoryHint: .isDirectory)
        let lowTide = music.appending(path: "Low Tide Hours", directoryHint: .isDirectory)
        let lanterns = music.appending(path: "Paper Lanterns", directoryHint: .isDirectory)
        for folder in [lowTide, lanterns] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let coverA = try Fixtures.coverJPEG(red: 0.9, green: 0.7, blue: 0.2)
        let coverB = try Fixtures.coverJPEG(red: 0.8, green: 0.3, blue: 0.2)

        try await Fixtures.writeM4A(
            to: lowTide.appending(path: "01 - Glass Rooms.m4a"),
            tags: FixtureTags(title: "Glass Rooms", artist: "Maren Volk", albumArtist: "Maren Volk", album: "Low Tide Hours", track: 1, cover: coverA)
        )
        try Fixtures.writeMP3(
            to: lowTide.appending(path: "02 - Undertow.mp3"),
            tags: FixtureTags(title: "Undertow", artist: "Maren Volk", albumArtist: "Maren Volk", album: "Low Tide Hours", track: 2, cover: coverA)
        )
        try Fixtures.writeFLAC(
            to: lanterns.appending(path: "Lantern Song.flac"),
            tags: FixtureTags(title: "Lantern Song", artist: "The Quiet Arcade", albumArtist: "The Quiet Arcade", album: "Paper Lanterns", track: 1, cover: coverB)
        )
        try Fixtures.writeWAV(to: lanterns.appending(path: "03 - Loose Demo.wav"))
        try Data("not audio".utf8).write(to: lanterns.appending(path: "cover.txt"))
        try Fixtures.writeWAV(to: music.appending(path: ".hidden.wav"))
        return music
    }

    /// Plain WAV files that import as tracks titled "Track 1"… and play for `seconds`.
    func makePlainTracks(count: Int, seconds: Double = 2) throws -> [URL] {
        let folder = root.appending(path: "plain", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try (1...count).map { index in
            let url = folder.appending(path: "Track \(index).wav")
            try Fixtures.writeWAV(to: url, seconds: seconds, frequency: 220 * Double(index))
            return url
        }
    }
}

/// Polls until `condition` holds or the timeout passes.
@MainActor
func waitUntil(timeout: Duration = .seconds(6), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(40))
    }
    return condition()
}
