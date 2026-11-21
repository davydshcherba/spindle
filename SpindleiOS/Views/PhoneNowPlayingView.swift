import SwiftUI

/// The full player, as a sheet over the app: a big cover, the title, the progress bar with the
/// start time at its left end and the time left at its right end, the transport controls, and a row
/// for the queue, the equalizer, playlists and more. Volume is the phone's own buttons.
struct PhoneNowPlayingView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app
    @Environment(LibraryViewModel.self) private var library
    @Environment(PhoneNavigator.self) private var navigator
    @Environment(CoverImporter.self) private var covers
    @Environment(Equalizer.self) private var equalizer

    @State private var isAddToPlaylistPresented = false
    @State private var trackBeingEdited: Track?

    var body: some View {
        @Bindable var app = app

        ZStack {
            AmbientBackground()

            GeometryReader { geometry in
                let side = max(150, min(geometry.size.width - 72, geometry.size.height - 440))
                VStack(spacing: 22) {
                    Text(player.contextLabel.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .frame(height: 14)

                    Spacer(minLength: 0)

                    Swap(id: player.currentItem?.artworkKey, style: .cover) {
                        ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 768, cornerRadius: 20)
                    }
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.4), radius: 28, y: 14)

                    info
                    timeline
                    TransportControls(playSize: 72, iconSize: 20, spacing: 22)
                    actions

                    Spacer(minLength: 0)
                }
                .padding(.top, 34)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $app.isQueueVisible) { PhoneQueueView() }
        .sheet(isPresented: $app.isEqualizerPresented) {
            EqualizerPanel()
                .presentationDetents([.fraction(0.5), .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $isAddToPlaylistPresented) {
            if let track = player.currentTrack { PhoneAddToPlaylistSheet(tracks: [track]) }
        }
        .sheet(item: $trackBeingEdited) { TrackEditorSheet(track: $0, library: library, covers: covers) }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var info: some View {
        VStack(spacing: 5) {
            Swap(id: player.currentItem?.id) {
                Text(player.currentItem?.title ?? "")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            Swap(id: player.currentItem?.id, delay: 0.04) {
                Text(player.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text.opacity(0.65))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 28)
    }

    /// The start time at the left end of the bar, the time left at its right end.
    private var timeline: some View {
        HStack(spacing: 10) {
            Text(player.elapsedText)
                .frame(minWidth: 42, alignment: .trailing)
            SeekBar(
                progress: player.progress,
                thickness: 5,
                thumbSize: 16,
                accessibilityName: "Playback position",
                onBegan: { player.beginScrub() },
                onChanged: { player.updateScrub($0) },
                onEnded: { player.endScrub(at: $0) }
            )
            .animation(Motion.swap, value: player.currentItem?.id)
            Text(player.remainingText)
                .frame(minWidth: 42, alignment: .leading)
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .foregroundStyle(Theme.text.opacity(0.65))
        .padding(.horizontal, 20)
    }

    // MARK: Actions

    private var actions: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 18) {
                IconButton(
                    systemName: "text.badge.plus", size: 18, help: "Add to playlist",
                    isEnabled: player.currentTrack != nil, glass: true, diameter: 54
                ) { isAddToPlaylistPresented = true }

                IconButton(
                    systemName: "list.bullet", size: 18, help: "Queue", isEnabled: player.hasItem,
                    glass: true, diameter: 54
                ) { app.isQueueVisible = true }

                IconButton(
                    systemName: "slider.vertical.3", size: 18,
                    color: equalizer.isShapingSound ? Theme.accentLight : Theme.muted,
                    help: "Equalizer", glass: true, diameter: 54
                ) { app.isEqualizerPresented = true }

                moreMenu
            }
        }
        .padding(.top, 4)
    }

    private var moreMenu: some View {
        Menu {
            if let track = player.currentTrack {
                Button("Edit Info\u{2026}", systemImage: "pencil") { trackBeingEdited = track }
                Divider()
                Button("Go to Album", systemImage: "square.stack") { show(.album(track.albumKey)) }
                Button("Go to Artist", systemImage: "person") { show(.artist(track.albumArtist.lowercased())) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(width: 54, height: 54)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .disabled(player.currentTrack == nil)
        .accessibilityLabel("More")
    }

    /// Leaves the player and opens the page.
    private func show(_ route: Route) {
        app.dismissNowPlaying()
        navigator.open(route)
    }
}
