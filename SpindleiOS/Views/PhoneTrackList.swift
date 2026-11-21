import SwiftUI

/// The rows of a song list. Tap to play; swipe for "play next" and "add to queue" (or "remove",
/// in a playlist); press and hold for the full menu.
struct PhoneTrackRows: View {
    let tracks: [Track]
    let context: String
    /// Show each song's position instead of its cover (an album's own page).
    var numbered = false
    var onRemove: ((Track) -> Void)?

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
            Button {
                player.play(track, in: tracks, context: context)
            } label: {
                PhoneTrackRow(
                    track: track, number: numbered ? index + 1 : nil,
                    isCurrent: player.isCurrent(track), isPlaying: player.isPlaying
                )
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Theme.hairline)
            .contextMenu { TrackContextMenu(track: track, tracks: tracks, context: context, onRemove: onRemove) }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { player.playNext([track]) } label: {
                    Label("Play Next", systemImage: "text.insert")
                }
                .tint(Theme.accent)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let onRemove {
                    Button(role: .destructive) { onRemove(track) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } else {
                    Button { player.addToQueue([track]) } label: {
                        Label("Add to Queue", systemImage: "text.append")
                    }
                    .tint(Color(hex: 0x4A6FA5))
                }
            }
        }
    }
}

/// A list of songs on its own.
struct PhoneTrackList: View {
    let tracks: [Track]
    let context: String

    var body: some View {
        List { PhoneTrackRows(tracks: tracks, context: context) }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }
}

private struct PhoneTrackRow: View {
    let track: Track
    let number: Int?
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28)
            } else {
                ArtworkView(key: track.artworkKey, pixelSize: 112, cornerRadius: 8)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accentLight : Theme.text)
                    .lineLimit(1)
                Text(number == nil ? "\(track.artist) \u{00B7} \(track.album)" : track.artist)
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
        .accessibilityElement(children: .combine)
    }
}
