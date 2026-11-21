import SwiftUI

/// The iPhone app's first screen: your songs, search, a mini player at the bottom and the full
/// player on top of it.
struct PhoneRootView: View {
    @Environment(AppViewModel.self) private var app
    @Environment(LibraryViewModel.self) private var library
    @Environment(PlayerViewModel.self) private var player
    @Environment(ImportViewModel.self) private var importer
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        @Bindable var app = app
        @Bindable var library = library

        NavigationStack {
            content
                // The navigation stack paints its own backdrop; this swaps it for Spindle's.
                .containerBackground(for: .navigation) { AmbientBackground() }
                .navigationTitle("My Music")
                // At the top (pull the list down), so the bottom is free for the mini player.
                .searchable(
                    text: $library.searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Songs, albums, artists"
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { addMenu }
                }
        }
        // The mini player floats above the home indicator; the list scrolls underneath it.
        .safeAreaInset(edge: .bottom, spacing: 0) { PhoneMiniPlayer() }
        .sheet(isPresented: $app.isNowPlayingPresented) { PhoneNowPlayingView() }
        .sheet(isPresented: $app.isAddMusicPresented, onDismiss: { importer.close() }) { PhoneImportSheet() }
        .overlay(alignment: .bottom) {
            if let message = toasts.message {
                ToastView(message: message)
                    .padding(.bottom, player.hasItem ? 96 : 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: toasts.message)
        .preferredColorScheme(.dark)
        // The backdrop picks up the colour of the cover that's playing.
        .task(id: player.currentItem?.artworkKey) { await player.refreshTint() }
        .onAppear {
            library.layout = .list
            library.sort = .title
        }
    }

    @ViewBuilder private var content: some View {
        if library.isLibraryEmpty {
            PhoneEmptyLibrary()
        } else if library.hasNoResults {
            ContentUnavailableView.search(text: library.searchText)
        } else {
            PhoneSongList()
        }
    }

    private var addMenu: some View {
        Menu {
            Button { Task { await importer.chooseFiles() } } label: {
                Label("Add songs\u{2026}", systemImage: "music.note")
            }
            Button { Task { await importer.chooseFolder() } } label: {
                Label("Add a folder\u{2026}", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add music")
    }
}

// MARK: - Songs

private struct PhoneSongList: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        let tracks = library.visibleTracks
        List(tracks) { track in
            Button {
                player.play(track, in: tracks, context: "My Music")
            } label: {
                PhoneTrackRow(track: track, isCurrent: player.isCurrent(track), isPlaying: player.isPlaying)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Theme.hairline)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct PhoneTrackRow: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: track.artworkKey, pixelSize: 112, cornerRadius: 8)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accentLight : Theme.text)
                    .lineLimit(1)
                Text("\(track.artist) \u{00B7} \(track.album)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentLight)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying)
            }
            Text(TimeFormat.clock(track.duration))
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty

private struct PhoneEmptyLibrary: View {
    @Environment(ImportViewModel.self) private var importer

    var body: some View {
        VStack(spacing: 14) {
            VinylDisc()
                .frame(width: 128, height: 128)
                .padding(.bottom, 10)
            Text("Your library is empty")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Add MP3, FLAC, M4A or WAV files from the Files app. No accounts, no streaming \u{2014} just your music.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Button { Task { await importer.chooseFiles() } } label: {
                Label("Add music", systemImage: "plus")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(AccentButtonStyle(height: 50))
            .padding(.top, 10)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
