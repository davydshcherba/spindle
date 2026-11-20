import SwiftUI

/// Column widths for track rows, derived from the available width so every row
/// lines up with the header without a per-row GeometryReader.
struct TrackColumns {
    static let number: CGFloat = 52
    static let duration: CGFloat = 72

    let title: CGFloat
    let artist: CGFloat
    let album: CGFloat
    let action: CGFloat

    init(totalWidth: CGFloat, action: CGFloat) {
        self.action = action
        let flexible = max(320, totalWidth - Self.number - Self.duration - action - 24)
        title = flexible * 0.42
        artist = flexible * 0.27
        album = flexible * 0.31
    }
}

/// A table of tracks: # · cover + title · artist · album · duration.
/// Lives inside a page's ScrollView. Pass `onRemove` to show a "remove" action (playlists).
struct TrackListView: View {
    let tracks: [Track]
    let context: String
    var onRemove: ((Track) -> Void)?

    @State private var width: CGFloat = 900

    var body: some View {
        let columns = TrackColumns(totalWidth: width, action: onRemove == nil ? 44 : 84)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ColumnHeader(title: "#").frame(width: TrackColumns.number)
                ColumnHeader(title: "TITLE").frame(width: columns.title, alignment: .leading)
                ColumnHeader(title: "ARTIST").frame(width: columns.artist, alignment: .leading)
                ColumnHeader(title: "ALBUM").frame(width: columns.album, alignment: .leading)
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .frame(width: TrackColumns.duration, alignment: .trailing)
                    .accessibilityLabel("Duration")
                Spacer().frame(width: columns.action)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)

            Divider().overlay(Theme.hairline)

            LazyVStack(spacing: 2) {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track, number: index + 1, tracks: tracks,
                        context: context, columns: columns, onRemove: onRemove
                    )
                }
            }
            .padding(.top, 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

struct TrackRow: View {
    let track: Track
    let number: Int
    let tracks: [Track]
    let context: String
    let columns: TrackColumns
    var onRemove: ((Track) -> Void)?

    @Environment(PlayerViewModel.self) private var player
    @State private var isHovering = false
    @State private var isPickerPresented = false

    var body: some View {
        let isCurrent = player.isCurrent(track)

        HStack(spacing: 0) {
            numberCell(isCurrent: isCurrent)
                .frame(width: TrackColumns.number)

            HStack(spacing: 14) {
                cover
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isCurrent ? Theme.accentLight : Theme.text)
                    .lineLimit(1)
            }
            .frame(width: columns.title, alignment: .leading)

            Text(track.artist)
                .lineLimit(1)
                .frame(width: columns.artist, alignment: .leading)
            Text(track.album)
                .lineLimit(1)
                .frame(width: columns.album, alignment: .leading)
            Text(TimeFormat.clock(track.duration))
                .monospacedDigit()
                .frame(width: TrackColumns.duration, alignment: .trailing)

            actions.frame(width: columns.action, alignment: .trailing)
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 8)
        .frame(height: 60)
        .background(
            isHovering ? Theme.surface : .clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { play() }
        .contextMenu { TrackContextMenu(track: track, tracks: tracks, context: context, onRemove: onRemove) }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Play") { play() }
    }

    private func play() { player.play(track, in: tracks, context: context) }

    @ViewBuilder private func numberCell(isCurrent: Bool) -> some View {
        if isCurrent {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentLight)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: player.isPlaying)
                .accessibilityLabel("Now playing")
        } else {
            Text("\(number)").monospacedDigit()
        }
    }

    private var cover: some View {
        Button(action: play) {
            ZStack {
                ArtworkView(key: track.artworkKey, pixelSize: 128, cornerRadius: 6)
                if isHovering {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.black.opacity(0.5))
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            if let onRemove {
                rowButton("xmark", help: "Remove from playlist") { onRemove(track) }
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(isHovering)
            }
            rowButton("plus", help: "Add to playlist") { isPickerPresented = true }
                .opacity(isHovering || isPickerPresented ? 1 : 0)
                .allowsHitTesting(isHovering || isPickerPresented)
                .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
                    AddToPlaylistPopover(tracks: [track]) { isPickerPresented = false }
                }
        }
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
