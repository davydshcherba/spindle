import SwiftUI

/// Full-page player: large cover, big progress bar and controls, and a background
/// tinted by the cover's dominant colour. Replaces the whole window while open.
struct NowPlayingView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app
    @State private var isPickerPresented = false

    var body: some View {
        ZStack {
            background

            GeometryReader { geometry in
                let coverSide = min(max(geometry.size.height - 440, 220), 470)
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 10)
                    cover(side: coverSide)
                    info.padding(.top, 30)
                    progress.padding(.top, 22)
                    TransportControls(playSize: 84, iconSize: 20, spacing: 38)
                        .padding(.top, 14)
                    Spacer(minLength: 10)
                    bottomBar
                }
                // Make room for the queue so nothing is hidden underneath it.
                .padding(.trailing, app.isQueueVisible ? QueuePanel.width : 0)
            }
            .ignoresSafeArea(.container, edges: .top)

            if app.isQueueVisible {
                QueuePanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: app.isQueueVisible)
        .task(id: player.currentItem?.artworkKey) { await player.refreshTint() }
        .onChange(of: player.hasItem) { _, hasItem in
            if !hasItem { app.dismissNowPlaying() }
        }
        .onExitCommand { app.dismissNowPlaying() }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Background

    private var background: some View {
        let tint = player.tint.map(Color.init) ?? Theme.surface
        return ZStack {
            Theme.background
            RadialGradient(
                colors: [tint.opacity(0.62), tint.opacity(0.18), .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 780
            )
            LinearGradient(
                colors: [.clear, Theme.background.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: player.tint)
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack {
            Text(player.contextLabel.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Theme.text.opacity(0.65))

            HStack {
                IconButton(systemName: "chevron.down", size: 15, color: Theme.text, help: "Close Now Playing") {
                    app.dismissNowPlaying()
                }
                .padding(.leading, 78)
                Spacer()
                Menu {
                    Button(app.isQueueVisible ? "Hide Queue" : "Show Queue") { app.isQueueVisible.toggle() }
                    Button(player.currentTrack?.isFavorite == true ? "Remove from Liked" : "Add to Liked") {
                        player.toggleFavoriteOfCurrent()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(.trailing, 24)
                .accessibilityLabel("More")
            }
        }
        .frame(height: 62)
    }

    private func cover(side: CGFloat) -> some View {
        ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 1024, cornerRadius: 16)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.5), radius: 34, y: 18)
            .scaleEffect(player.isPlaying ? 1 : 0.93)
            .animation(.spring(duration: 0.5, bounce: 0.25), value: player.isPlaying)
    }

    private var info: some View {
        VStack(spacing: 6) {
            Text(player.currentItem?.title ?? "")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text(player.subtitle)
                .font(.system(size: 17))
                .foregroundStyle(Theme.text.opacity(0.6))
                .lineLimit(1)
        }
        .padding(.horizontal, 60)
        .multilineTextAlignment(.center)
    }

    private var progress: some View {
        VStack(spacing: 2) {
            SeekBar(
                progress: player.progress,
                thickness: 5,
                thumbSize: 16,
                accessibilityName: "Playback position",
                onBegan: { player.beginScrub() },
                onChanged: { player.updateScrub($0) },
                onEnded: { player.endScrub(at: $0) }
            )
            HStack {
                Text(player.elapsedText)
                Spacer()
                Text(player.remainingText)
            }
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(Theme.text.opacity(0.6))
        }
        .frame(maxWidth: 800)
        .padding(.horizontal, 40)
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 26) {
                LabelButton(title: "Add to playlist", systemImage: "text.badge.plus") {
                    isPickerPresented = true
                }
                .disabled(player.currentTrack == nil)
                .popover(isPresented: $isPickerPresented, arrowEdge: .top) {
                    if let track = player.currentTrack {
                        AddToPlaylistPopover(tracks: [track]) { isPickerPresented = false }
                    }
                }

                LabelButton(
                    title: "Queue", systemImage: "list.bullet",
                    tint: app.isQueueVisible ? Theme.accentLight : Theme.muted
                ) { app.isQueueVisible.toggle() }

                let isFavorite = player.currentTrack?.isFavorite == true
                LabelButton(
                    title: isFavorite ? "Liked" : "Like",
                    systemImage: isFavorite ? "heart.fill" : "heart",
                    tint: isFavorite ? Theme.accentLight : Theme.muted,
                    hoverTint: Theme.accentLight
                ) { player.toggleFavoriteOfCurrent() }
            }
            Spacer()
            HStack(spacing: 8) {
                IconButton(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 15, help: player.isMuted ? "Unmute" : "Mute") {
                    player.toggleMute()
                }
                SeekBar(
                    progress: player.volume,
                    thickness: 4,
                    thumbSize: 12,
                    fill: Theme.text,
                    accessibilityName: "Volume",
                    onChanged: { player.volume = $0 },
                    onEnded: { player.volume = $0 }
                )
                .frame(width: 150)
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 28)
    }
}

private struct LabelButton: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.muted
    var hoverTint: Color = Theme.text
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHovering ? hoverTint : tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
