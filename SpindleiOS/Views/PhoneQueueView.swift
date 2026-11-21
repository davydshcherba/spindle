import SwiftUI

/// What is playing and what comes next. Tap a song to jump to it; swipe it to take it out.
struct PhoneQueueView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = player.currentEntry {
                    Section("Now playing") {
                        QueueRow(entry: current, isCurrent: true, isPlaying: player.isPlaying)
                            .listRowBackground(Color.clear)
                    }
                }
                Section("Next up") {
                    if player.upNext.isEmpty {
                        Text(player.repeatMode == .all ? "Playback continues from the start." : "Nothing up next.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(player.upNext) { entry in
                            Button { player.jump(to: entry) } label: {
                                QueueRow(entry: entry, isCurrent: false, isPlaying: false)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { player.removeFromQueue(entry) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .animation(Motion.swap, value: player.upNext.map(\.id))
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

private struct QueueRow: View {
    let entry: QueueEntry
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: entry.item.artworkKey, pixelSize: 112, cornerRadius: 8)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accentLight : Theme.text)
                    .lineLimit(1)
                Text(entry.item.artist)
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
            } else {
                Text(TimeFormat.clock(entry.item.duration))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
