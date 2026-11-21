import SwiftUI

/// The iPhone app: two tabs (My Music, Playlists), the mini player above the tab bar, and the
/// full player, editors and import progress as sheets over them.
struct PhoneRootView: View {
    @Environment(AppViewModel.self) private var app
    @Environment(PlayerViewModel.self) private var player
    @Environment(ToastCenter.self) private var toasts
    @State private var navigator = PhoneNavigator()

    var body: some View {
        @Bindable var navigator = navigator

        TabView(selection: $navigator.tab) {
            // `SwiftUI.Tab`: the app already has its own `Tab` (for the Mac's navigation).
            SwiftUI.Tab("My Music", systemImage: "music.quarternote.3", value: PhoneNavigator.Tab.library) {
                PhoneLibraryView()
            }
            SwiftUI.Tab("Playlists", systemImage: "music.note.list", value: PhoneNavigator.Tab.playlists) {
                PhonePlaylistsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: player.hasItem) { PhoneMiniPlayer() }
        .environment(self.navigator)
        .modifier(PhoneSheets(navigator: self.navigator))
        .overlay(alignment: .bottom) {
            if let message = toasts.message {
                ToastView(message: message)
                    .padding(.bottom, player.hasItem ? 150 : 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: toasts.message)
        .preferredColorScheme(.dark)
        // The backdrop picks up the colour of the cover that's playing.
        .task(id: player.currentItem?.artworkKey) { await player.refreshTint() }
        // Pages opened the Mac way (`app.navigate`) show up on the phone's stacks too.
        .onChange(of: app.route) { _, route in self.navigator.open(route) }
    }
}

/// The sheets and dialogs that can come up over any tab.
private struct PhoneSheets: ViewModifier {
    let navigator: PhoneNavigator

    @Environment(AppViewModel.self) private var app
    @Environment(LibraryViewModel.self) private var library
    @Environment(PlayerViewModel.self) private var player
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(ImportViewModel.self) private var importer
    @Environment(ToastCenter.self) private var toasts
    @Environment(CoverImporter.self) private var covers

    func body(content: Content) -> some View {
        @Bindable var app = app

        content
            .sheet(isPresented: $app.isNowPlayingPresented, onDismiss: { app.dismissNowPlaying() }) {
                PhoneNowPlayingView().environment(navigator)
            }
            .sheet(isPresented: $app.isAddMusicPresented, onDismiss: { importer.close() }) { PhoneImportSheet() }
            .sheet(item: $app.playlistEditor) { editor in
                PlaylistEditorSheet(editor: editor, playlists: playlists, covers: covers) { created in
                    navigator.open(.playlist(created))
                }
            }
            .sheet(item: $app.albumBeingEdited) { album in
                AlbumEditorSheet(album: album, library: library, covers: covers) { newID in
                    // The album's id changes with its name; keep the open page pointing at it.
                    if navigator.libraryPath.last == .album(album.id) {
                        navigator.libraryPath[navigator.libraryPath.count - 1] = .album(newID)
                    }
                }
            }
            .sheet(item: $app.trackBeingEdited) { track in
                TrackEditorSheet(track: track, library: library, covers: covers)
            }
            .confirmationDialog(
                "Delete \u{201C}\(pendingDeletionName)\u{201D}?",
                isPresented: Binding(
                    get: { app.playlistPendingDeletion != nil },
                    set: { if !$0 { app.playlistPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Playlist", role: .destructive) { confirmDeletion() }
            } message: {
                Text("The songs stay in your library.")
            }
            .onChange(of: player.errorMessage) { _, message in
                guard let message else { return }
                toasts.show(message, duration: .seconds(5))
                player.dismissError()
            }
            .onChange(of: library.errorMessage) { _, message in
                guard let message else { return }
                toasts.show(message, duration: .seconds(6))
                library.dismissError()
            }
    }

    private var pendingDeletionName: String {
        app.playlistPendingDeletion.flatMap { playlists.summary(for: $0)?.name } ?? "playlist"
    }

    private func confirmDeletion() {
        guard let id = app.playlistPendingDeletion else { return }
        app.playlistPendingDeletion = nil
        if navigator.playlistsPath.last == .playlist(id) { navigator.playlistsPath.removeLast() }
        playlists.delete(id)
    }
}
