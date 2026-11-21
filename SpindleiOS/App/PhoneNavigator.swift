import Observation

/// Where the iPhone app is: which tab is showing, and what is pushed on each tab's stack.
@Observable
final class PhoneNavigator {
    enum Tab: Hashable { case library, playlists }

    var tab: Tab = .library
    var libraryPath: [Route] = []
    var playlistsPath: [Route] = []

    /// Shows a page from anywhere (the player, a menu): switches to the tab it belongs to.
    func open(_ route: Route) {
        switch route {
        case .myMusic:
            tab = .library
            libraryPath = []
        case .album, .artist:
            tab = .library
            libraryPath = [route]
        case .playlists:
            tab = .playlists
            playlistsPath = []
        case .playlist:
            tab = .playlists
            playlistsPath = [route]
        }
    }
}
