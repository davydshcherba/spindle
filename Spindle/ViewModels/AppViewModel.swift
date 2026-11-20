import Foundation
import Observation

enum Route: Hashable {
    case myMusic
    case playlists
    case playlist(UUID)
    case album(String)
    case artist(String)
}

enum Tab: Hashable {
    case myMusic
    case playlists
}

/// The "create or rename a playlist" sheet.
enum PlaylistEditor: Identifiable, Equatable {
    case create(adding: [UUID])
    case rename(UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .rename(let id): "rename-\(id)"
        }
    }
}

/// Navigation and presentation state for the whole window.
@Observable
final class AppViewModel {
    private(set) var route: Route = .myMusic
    private var backStack: [Route] = []
    private var forwardStack: [Route] = []

    var isNowPlayingPresented = false
    var isQueueVisible = false
    var isAddMusicPresented = false
    var playlistEditor: PlaylistEditor?
    var playlistPendingDeletion: UUID?

    var tab: Tab {
        switch route {
        case .myMusic, .album, .artist: .myMusic
        case .playlists, .playlist: .playlists
        }
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func navigate(to destination: Route) {
        guard destination != route else { return }
        backStack.append(route)
        forwardStack.removeAll()
        route = destination
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(route)
        route = previous
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(route)
        route = next
    }

    func show(_ tab: Tab) {
        navigate(to: tab == .myMusic ? .myMusic : .playlists)
    }

    func presentNowPlaying() { isNowPlayingPresented = true }

    func dismissNowPlaying() {
        isNowPlayingPresented = false
        isQueueVisible = false
    }

    func presentAddMusic() { isAddMusicPresented = true }
    func newPlaylist(adding trackIDs: [UUID] = []) { playlistEditor = .create(adding: trackIDs) }
}
