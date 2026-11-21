#if DEBUG
import Foundation

/// Development aid, compiled out of release builds.
///
/// Launch the debug build with environment variables to start in a known state:
///
///     SPINDLE_SEED_DIR=/path/inside/container   import this folder once if the library is empty
///     SPINDLE_SCREEN=list,play                  comma-separated: grid, list, artists, recent, playlists,
///                                               playlist, album, play, nowplaying, queue, add, edit, albumedit, playlistedit
///
/// The app is sandboxed, so the seed folder must be readable by it (e.g. inside its container).
extension AppModel {
    func applyDebugLaunchOptions() {
        let env = ProcessInfo.processInfo.environment
        guard env["XCTestConfigurationFilePath"] == nil else { return }
        let seed = env["SPINDLE_SEED_DIR"]
        let screens = Set((env["SPINDLE_SCREEN"] ?? "").split(separator: ",").map(String.init))
        guard seed != nil || !screens.isEmpty else { return }

        Task {
            let library = environment.library
            if let seed, library.tracks.isEmpty {
                library.importItems([URL(fileURLWithPath: seed)])
                await library.waitForImport()
                library.dismissImportSession()
                if library.playlists.isEmpty { seedPlaylists() }
            }

            if screens.contains("list") { self.library.layout = .list }
            if screens.contains("albums") { self.library.filter = .albums; self.library.layout = .grid }
            if screens.contains("artists") { self.library.filter = .artists }
            if screens.contains("recent") { self.library.filter = .recentlyAdded }
            if screens.contains("playlists") { app.navigate(to: .playlists) }
            if screens.contains("playlist"), let first = playlists.summaries.first {
                app.navigate(to: .playlist(first.id))
            }
            if screens.contains("album"), let first = self.library.visibleAlbums.first {
                app.navigate(to: .album(first.id))
            }
            if screens.contains("add") { app.presentAddMusic() }
            if screens.contains("edit"), let first = self.library.visibleTracks.first { app.edit(first) }
            if screens.contains("albumedit"), let first = self.library.visibleAlbums.first { app.edit(first) }
            if screens.contains("playlistedit"), let first = playlists.summaries.first {
                app.playlistEditor = .edit(first.id)
            }

            let wantsPlayback = !screens.isDisjoint(with: ["play", "nowplaying", "queue"])
            if wantsPlayback, let first = self.library.visibleTracks.first {
                environment.player.volume = 0
                player.play(first, in: self.library.visibleTracks, context: "My Music")
                player.service.seek(to: 134)
            }
            if screens.contains("nowplaying") || screens.contains("queue") { app.presentNowPlaying() }
            if screens.contains("queue") { app.isQueueVisible = true }
            if screens.contains("eq") { app.presentNowPlaying(); app.isEqualizerPresented = true }
        }
    }

    private func seedPlaylists() {
        let tracks = environment.library.tracks
        guard !tracks.isEmpty else { return }
        let names = ["Late Night Drive", "Focus Mode", "Sunday Kitchen", "Gym Rotation"]
        for (index, name) in names.enumerated() {
            let slice = tracks.enumerated().filter { $0.offset % names.count == index || $0.offset % 5 == index }.map(\.element.id)
            environment.library.createPlaylist(named: name, adding: Array(slice.prefix(12)))
        }
    }
}
#endif
