import SwiftUI

/// Top bar, current page and player bar. Now Playing and the Add music dialog
/// are overlays on top of this, so the player bar is on every page.
struct RootView: View {
    @Environment(AppViewModel.self) private var app
    @Environment(ImportViewModel.self) private var importer
    @Environment(PlayerViewModel.self) private var player
    @Environment(LibraryViewModel.self) private var library
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        @Bindable var app = app

        ZStack {
            VStack(spacing: 0) {
                TopBar()
                page
                    .id(app.route)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PlayerBar()
            }
            // The title bar is hidden: let the top bar run underneath the traffic lights.
            .ignoresSafeArea(.container, edges: .top)
            .blur(radius: app.isAddMusicPresented ? 10 : 0)

            if app.isAddMusicPresented {
                AddMusicView().transition(.opacity)
            }

            if app.isNowPlayingPresented {
                NowPlayingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            dropHighlight
        }
        .overlay(alignment: .bottom) {
            if let message = toasts.message {
                ToastView(message: message)
                    .padding(.bottom, app.isNowPlayingPresented ? 110 : 118)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .animation(.smooth(duration: 0.22), value: app.route)
        .animation(.smooth(duration: 0.2), value: app.isAddMusicPresented)
        .animation(.smooth(duration: 0.4), value: app.isNowPlayingPresented)
        .animation(.smooth(duration: 0.25), value: toasts.message)
        .frame(minWidth: 980, minHeight: 640)
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .dropDestination(for: URL.self) { urls, _ in
            importer.handleDrop(urls)
        } isTargeted: { importer.isDropTargeted = $0 }
        .sheet(item: $app.playlistEditor) { editor in
            PlaylistNameSheet(editor: editor)
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

    @ViewBuilder private var page: some View {
        switch app.route {
        case .myMusic: MyMusicView()
        case .playlists: PlaylistsView()
        case .playlist(let id): PlaylistDetailView(playlistID: id)
        case .album(let id): AlbumDetailView(albumID: id)
        case .artist(let id): ArtistDetailView(artistID: id)
        }
    }

    /// Shown while files are dragged over the window and the dialog isn't open.
    @ViewBuilder private var dropHighlight: some View {
        if importer.isDropTargeted, !app.isAddMusicPresented {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accentLight, style: StrokeStyle(lineWidth: 3, dash: [12, 8]))
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    Label("Drop to add music", systemImage: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .padding(10)
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(4)
        }
    }

    private var pendingDeletionName: String {
        app.playlistPendingDeletion.flatMap { playlists.summary(for: $0)?.name } ?? "playlist"
    }

    private func confirmDeletion() {
        guard let id = app.playlistPendingDeletion else { return }
        app.playlistPendingDeletion = nil
        if case .playlist(let open) = app.route, open == id { app.goBack() }
        playlists.delete(id)
    }
}
