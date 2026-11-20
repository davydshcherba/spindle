import Foundation
import SwiftData

/// Owns the services (via `AppEnvironment`) and every view model, wired together once.
final class AppModel {
    let environment: AppEnvironment
    let toasts = ToastCenter()
    let app = AppViewModel()
    let library: LibraryViewModel
    let playlists: PlaylistsViewModel
    let player: PlayerViewModel
    let importer: ImportViewModel

    init() throws {
        environment = try AppEnvironment.makeForCurrentProcess()
        let services = environment

        library = LibraryViewModel(library: services.library, player: services.player)
        playlists = PlaylistsViewModel(library: services.library, toasts: toasts)
        player = PlayerViewModel(service: services.player, library: services.library, artwork: services.artwork)
        #if os(macOS)
        let picker: any FilePicking = MacFilePicker()
        #endif
        importer = ImportViewModel(library: services.library, picker: picker, app: app, toasts: toasts)

        #if DEBUG
        applyDebugLaunchOptions()
        #endif
    }

    var artwork: ArtworkStore { environment.artwork }
}
