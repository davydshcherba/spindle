import Foundation
import Testing
@testable import Spindle

/// Which tab shows, and what each tab's stack holds, as pages are opened from anywhere.
@MainActor
struct PhoneNavigatorTests {
    @Test func startsOnMyMusicWithNothingPushed() {
        let navigator = PhoneNavigator()
        #expect(navigator.tab == .library)
        #expect(navigator.libraryPath.isEmpty)
        #expect(navigator.playlistsPath.isEmpty)
    }

    @Test func anAlbumOrArtistOpensOnMyMusic() {
        let navigator = PhoneNavigator()
        navigator.tab = .playlists

        navigator.open(.album("album-key"))
        #expect(navigator.tab == .library)
        #expect(navigator.libraryPath == [.album("album-key")])

        navigator.tab = .playlists
        navigator.open(.artist("artist-key"))
        #expect(navigator.tab == .library)
        #expect(navigator.libraryPath == [.artist("artist-key")], "it replaces the page that was open, not stacks on it")
    }

    @Test func aPlaylistOpensOnPlaylists() {
        let navigator = PhoneNavigator()
        let playlist = UUID()

        navigator.open(.playlist(playlist))

        #expect(navigator.tab == .playlists)
        #expect(navigator.playlistsPath == [.playlist(playlist)])
        #expect(navigator.libraryPath.isEmpty, "the other tab's pages are left alone")
    }

    @Test func theTopLevelPagesClearTheirTab() {
        let navigator = PhoneNavigator()
        navigator.open(.album("album-key"))
        navigator.open(.playlist(UUID()))

        navigator.open(.myMusic)
        #expect(navigator.tab == .library)
        #expect(navigator.libraryPath.isEmpty)

        navigator.open(.playlists)
        #expect(navigator.tab == .playlists)
        #expect(navigator.playlistsPath.isEmpty)
    }
}
