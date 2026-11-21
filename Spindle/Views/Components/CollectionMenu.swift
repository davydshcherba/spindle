import SwiftUI

/// Context menu shared by albums, artists and playlists-from-tracks.
struct CollectionMenu: View {
    let tracks: [Track]
    let context: String
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        Button("Play") { player.play(tracks, context: context) }
        Button("Shuffle") { player.play(tracks, context: context, shuffled: true) }
        Divider()
        Button("Play Next") { player.playNext(tracks) }
        Button("Add to Queue") { player.addToQueue(tracks) }
        Divider()
        AddToPlaylistMenu(tracks: tracks)
    }
}
