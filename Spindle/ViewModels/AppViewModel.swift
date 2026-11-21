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

/// The "create or edit a playlist" sheet.
enum PlaylistEditor: Identifiable, Equatable {
    case create(adding: [UUID])
    case edit(UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let id): "edit-\(id)"
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
    /// The equalizer sheet over Now Playing (on the phone; the Mac uses a popover of its own).
    var isEqualizerPresented = false
    var isAddMusicPresented = false
    var playlistEditor: PlaylistEditor?
    var playlistPendingDeletion: UUID?
    /// The track whose info is open in the editor sheet.
    var trackBeingEdited: Track?
    /// The album open in the album editor sheet.
    var albumBeingEdited: Album?

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
    func edit(_ track: Track) { trackBeingEdited = track }
    func edit(_ album: Album) { albumBeingEdited = album }

    /// Swaps the page being shown without adding a history entry (e.g. an album whose id changed).
    func replaceRoute(_ destination: Route) { route = destination }
    func newPlaylist(adding trackIDs: [UUID] = []) { playlistEditor = .create(adding: trackIDs) }
}
