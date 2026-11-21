import SwiftUI

/// Full-page player: a large cover over a backdrop made of its own colours, with Liquid Glass
/// controls floating on top. Replaces the whole window while open.
struct NowPlayingView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app
    @Environment(Equalizer.self) private var equalizer
    @State private var isPickerPresented = false
    @State private var isEqualizerPresented = false

    var body: some View {
        ZStack {
            background

            GeometryReader { geometry in
                let coverSide = min(max(geometry.size.height - 470, 220), 440)
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 8)
                    cover(side: coverSide)
                    info.padding(.top, 26)
                    timeline.padding(.top, 20)
                    TransportControls(playSize: 78, iconSize: 18, spacing: 16, glass: true)
                        .padding(.top, 16)
                    Spacer(minLength: 8)
                    bottomBar
                }
                // Make room for the floating queue so nothing is hidden underneath it.
                .padding(.trailing, app.isQueueVisible ? QueuePanel.width + 16 : 0)
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

    /// The cover itself, blown up and blurred, so the glass above has real colour to refract.
    private var background: some View {
        let tint = player.tint.map(Color.init) ?? Theme.accent
        return ZStack {
            Theme.background
            if let key = player.currentItem?.artworkKey {
                ArtworkView(key: key, pixelSize: 128, cornerRadius: 0)
                    .frame(width: 400, height: 400)
                    .blur(radius: 20, opaque: true)
                    .scaleEffect(4)
                    .saturation(1.35)
                    .opacity(0.34)
                    .transition(.opacity)
            }
            // Keeps light covers from washing the page out: the mood stays dark.
            Theme.background.opacity(0.28)
            RadialGradient(
                colors: [tint.opacity(0.40), .clear],
                center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 720
            )
            LinearGradient(colors: [.clear, Theme.background.opacity(0.8)], startPoint: .center, endPoint: .bottom)
        }
        .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: player.currentItem?.artworkKey)
        .animation(.easeInOut(duration: 0.8), value: player.tint)
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack {
            Text(player.contextLabel.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Theme.text.opacity(0.7))

            HStack {
                IconButton(
                    systemName: "chevron.down", size: 15, color: Theme.text,
                    help: "Close Now Playing", glass: true, diameter: 40
                ) { app.dismissNowPlaying() }
                .padding(.leading, 74)
                Spacer()
                Menu {
                    Button(app.isQueueVisible ? "Hide Queue" : "Show Queue") { app.isQueueVisible.toggle() }
                    if let track = player.currentTrack {
                        Button("Edit Info\u{2026}") { app.edit(track) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular.interactive(), in: Circle())
                        .contentShape(Circle())
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
        // A new cover settles in over the old one when the track changes.
        Swap(id: player.currentItem?.artworkKey, style: .cover) {
            ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 1024, cornerRadius: 28)
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.45), radius: 36, y: 20)
        }
        .scaleEffect(player.isPlaying ? 1 : 0.93)
        .animation(.spring(duration: 0.5, bounce: 0.25), value: player.isPlaying)
    }

    private var info: some View {
        // Title first, artist a beat later.
        VStack(spacing: 6) {
            Swap(id: player.currentItem?.id) {
                Text(player.currentItem?.title ?? "")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            Swap(id: player.currentItem?.id, delay: 0.04) {
                Text(player.subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.text.opacity(0.65))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 60)
        .multilineTextAlignment(.center)
    }

    /// The progress bar on its own glass card, with the start time at its left end and the
    /// end time at its right end.
    private var timeline: some View {
        HStack(spacing: 14) {
            Text(player.elapsedText)
                .frame(minWidth: 46, alignment: .trailing)
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
                .frame(minWidth: 46, alignment: .leading)
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .foregroundStyle(Theme.text.opacity(0.65))
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: 720)
        .glassPanel(cornerRadius: 28)
        .padding(.horizontal, 40)
    }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 12) {
                LabelButton(title: "Add to playlist", systemImage: "text.badge.plus") {
                    isPickerPresented = true
                }
                .disabled(player.currentTrack == nil)
                .popover(isPresented: $isPickerPresented, arrowEdge: .top) {
                    if let track = player.currentTrack {
                        AddToPlaylistPopover(tracks: [track]) { isPickerPresented = false }
                    }
                }

                LabelButton(title: "Queue", systemImage: "list.bullet", isActive: app.isQueueVisible) {
                    app.isQueueVisible.toggle()
                }

                LabelButton(title: "Equalizer", systemImage: "slider.vertical.3", isActive: equalizer.isShapingSound) {
                    isEqualizerPresented = true
                }
                .popover(isPresented: $isEqualizerPresented, arrowEdge: .top) { EqualizerPanel() }

                Spacer()

                HStack(spacing: 8) {
                    IconButton(
                        systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 15,
                        help: player.isMuted ? "Unmute" : "Mute"
                    ) { player.toggleMute() }
                    SeekBar(
                        progress: player.volume,
                        thickness: 4,
                        thumbSize: 12,
                        fill: Theme.text,
                        accessibilityName: "Volume",
                        onChanged: { player.volume = $0 },
                        onEnded: { player.volume = $0 }
                    )
                    .frame(width: 140)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .glassEffect(.regular, in: Capsule())
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 26)
    }
}

/// A text button on its own Liquid Glass capsule.
private struct LabelButton: View {
    let title: String
    let systemImage: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isActive ? Color.white : Theme.text.opacity(0.9))
                .padding(.horizontal, 16)
                .frame(height: 40)
                .glassSelected(isActive, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
