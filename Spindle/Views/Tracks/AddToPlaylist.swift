import SwiftUI

/// The popover from a track's "+" button: pick a playlist or make a new one.
struct AddToPlaylistPopover: View {
    let tracks: [Track]
    let dismiss: () -> Void

    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ADD TO PLAYLIST")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            if playlists.summaries.isEmpty {
                Text("No playlists yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(playlists.summaries) { row($0) }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider().overlay(Theme.hairline).padding(.vertical, 6)

            Button {
                dismiss()
                app.newPlaylist(adding: tracks.map(\.id))
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.accentLight.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 34, height: 34)
                        .overlay(Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentLight))
                    Text("New playlist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accentLight)
                    Spacer()
                }
            }
            .buttonStyle(RowButtonStyle())
        }
        .padding(12)
        .frame(width: 290)
    }

    private func row(_ summary: PlaylistsViewModel.Summary) -> some View {
        let alreadyIn = tracks.count == 1 && summary.playlist.trackIDs.contains(tracks[0].id)
        return Button {
            playlists.add(tracks, to: summary.playlist)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 128, cornerRadius: 6)
                    .frame(width: 34, height: 34)
                Text(summary.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer()
                if alreadyIn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accentLight)
                        .accessibilityLabel("Already added")
                } else {
                    Text("\(summary.trackCount)")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .buttonStyle(RowButtonStyle())
    }
}

/// "Add to Playlist ▸" submenu for context menus.
struct AddToPlaylistMenu: View {
    let tracks: [Track]
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app

    var body: some View {
        Menu("Add to Playlist") {
            ForEach(playlists.summaries) { summary in
                Button(summary.name) { playlists.add(tracks, to: summary.playlist) }
            }
            if !playlists.summaries.isEmpty { Divider() }
            Button("New Playlist\u{2026}") { app.newPlaylist(adding: tracks.map(\.id)) }
        }
    }
}

/// Right-click menu for a track row.
struct TrackContextMenu: View {
    let track: Track
    let tracks: [Track]
    let context: String
    var onRemove: ((Track) -> Void)?

    @Environment(PlayerViewModel.self) private var player
    @Environment(LibraryViewModel.self) private var library
    @Environment(AppViewModel.self) private var app

    var body: some View {
        Button("Play") { player.play(track, in: tracks, context: context) }
        Button("Play Next") { player.playNext([track]) }
        Button("Add to Queue") { player.addToQueue([track]) }
        Divider()
        AddToPlaylistMenu(tracks: [track])
        Button("Edit Info\u{2026}") { app.edit(track) }
        Divider()
        if let onRemove {
            Button("Remove from Playlist", role: .destructive) { onRemove(track) }
        } else {
            Button("Remove from Library", role: .destructive) { library.remove([track]) }
        }
    }
}
