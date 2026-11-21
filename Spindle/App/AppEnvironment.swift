import Foundation
import SwiftData

/// The composition root: builds the object graph once and hands it to the UI.
final class AppEnvironment {
    let container: ModelContainer
    let artwork: ArtworkStore
    let library: LibraryService
    let equalizer: Equalizer
    let player: PlayerService
    let nowPlaying: NowPlayingService

    init(
        inMemory: Bool = false,
        artworkDirectory: URL = ArtworkStore.defaultDirectory(),
        defaults: UserDefaults = .standard
    ) throws {
        let schema = Schema([Track.self, Playlist.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: configuration)

        artwork = ArtworkStore(directory: artworkDirectory)
        library = LibraryService(modelContext: container.mainContext, artwork: artwork)
        equalizer = Equalizer(defaults: defaults)
        player = PlayerService(defaults: defaults, equalizer: equalizer.parameters)
        nowPlaying = NowPlayingService(player: player, artwork: artwork)

        let library = library
        player.onBookmarkRefreshed = { id, data in library.updateBookmark(forTrackWithID: id, to: data) }
    }

    /// The real app uses the on-disk store. Unit tests host the app, so they get a throwaway one
    /// instead of touching the user's library.
    static func makeForCurrentProcess() throws -> AppEnvironment {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            return try AppEnvironment()
        }
        return try AppEnvironment(
            inMemory: true,
            artworkDirectory: FileManager.default.temporaryDirectory.appending(path: "SpindleTestHost-\(UUID().uuidString)"),
            defaults: UserDefaults(suiteName: "SpindleTestHost") ?? .standard
        )
    }
}
