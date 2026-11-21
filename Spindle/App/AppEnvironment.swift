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
    #if os(iOS)
    let audioSession: AudioSessionHandler
    #endif

    init(
        inMemory: Bool = false,
        artworkDirectory: URL = ArtworkStore.defaultDirectory(),
        libraryDirectory: URL = LibraryFiles.defaultDirectory(),
        defaults: UserDefaults = .standard
    ) throws {
        let schema = Schema([Track.self, Playlist.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: configuration)

        artwork = ArtworkStore(directory: artworkDirectory)
        let files = LibraryFiles(directory: libraryDirectory)
        library = LibraryService(modelContext: container.mainContext, artwork: artwork, files: files)
        equalizer = Equalizer(defaults: defaults)
        player = PlayerService(defaults: defaults, equalizer: equalizer.parameters, files: files)
        nowPlaying = NowPlayingService(player: player, artwork: artwork)
        #if os(iOS)
        audioSession = AudioSessionHandler(player: player)
        #endif

        // Songs from before Spindle kept its own copies are copied in, once, in the background.
        let library = library
        Task { await library.migrateLegacyTracks() }
    }

    /// The real app uses the on-disk store. Unit tests host the app, so they get a throwaway one
    /// instead of touching the user's library.
    static func makeForCurrentProcess() throws -> AppEnvironment {
        let environment = ProcessInfo.processInfo.environment
        // UI tests launch the app itself (not hosted), so they ask for the same throwaway store by name.
        #if DEBUG
        let isUITest = environment["SPINDLE_UI_TESTING"] != nil
        #else
        let isUITest = false
        #endif
        guard environment["XCTestConfigurationFilePath"] != nil || isUITest else {
            return try AppEnvironment()
        }
        return try AppEnvironment(
            inMemory: true,
            artworkDirectory: FileManager.default.temporaryDirectory.appending(path: "SpindleTestHost-\(UUID().uuidString)"),
            libraryDirectory: FileManager.default.temporaryDirectory.appending(path: "SpindleTestHostMusic-\(UUID().uuidString)"),
            defaults: UserDefaults(suiteName: isUITest ? "SpindleUITest-\(UUID().uuidString)" : "SpindleTestHost") ?? .standard
        )
    }
}
