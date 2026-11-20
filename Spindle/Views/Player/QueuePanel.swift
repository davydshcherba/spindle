import SwiftUI

/// The play queue, as a panel that slides over the right side of Now Playing.
struct QueuePanel: View {
    static let width: CGFloat = 380

    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        sectionTitle("Now playing")
                        if let current = player.currentEntry {
                            Swap(id: current.id) { QueueRow(entry: current, isCurrent: true) }
                        }

                        sectionTitle("Next up").padding(.top, 14)
                        if player.upNext.isEmpty {
                            Text(player.repeatMode == .all ? "Playback continues from the start." : "Nothing up next.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(player.upNext) { QueueRow(entry: $0, isCurrent: false).transition(.opacity) }
                        }
                    }
                    // Removing or skipping past a song fades its row out and closes the gap.
                    .animation(Motion.swap, value: player.upNext.map(\.id))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: Self.width)
            .frame(maxHeight: .infinity)
            // A floating Liquid Glass panel rather than a full-height strip.
            .glassPanel(cornerRadius: 32)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Queue")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                if !player.contextLabel.isEmpty {
                    Text(player.contextLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            IconButton(systemName: "xmark", size: 13, help: "Close queue") { app.isQueueVisible = false }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

private struct QueueRow: View {
    let entry: QueueEntry
    let isCurrent: Bool

    @Environment(PlayerViewModel.self) private var player
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: entry.item.artworkKey, pixelSize: 128, cornerRadius: 6)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accentLight : Theme.text)
                    .lineLimit(1)
                Text(entry.item.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentLight)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: player.isPlaying)
                    .accessibilityLabel("Now playing")
            } else if isHovering {
                IconButton(systemName: "xmark", size: 11, help: "Remove from queue") {
                    player.removeFromQueue(entry)
                }
            } else {
                Text(TimeFormat.clock(entry.item.duration))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 56)
        .background(
            isHovering && !isCurrent ? Color.white.opacity(0.07) : .clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .animation(Motion.quick, value: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { if !isCurrent { player.jump(to: entry) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [] : .isButton)
    }
}
