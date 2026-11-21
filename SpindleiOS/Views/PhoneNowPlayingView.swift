import SwiftUI

/// The full player, as a sheet over the library: a big cover, the title, the progress bar with
/// the time at each end, and the transport controls. Volume is the phone's own buttons.
struct PhoneNowPlayingView: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 26) {
                Spacer(minLength: 16)

                Swap(id: player.currentItem?.artworkKey, style: .cover) {
                    ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 768, cornerRadius: 20)
                }
                .shadow(color: .black.opacity(0.4), radius: 28, y: 14)
                .padding(.horizontal, 36)

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

                timeline

                TransportControls(playSize: 72, iconSize: 20, spacing: 22)

                Spacer(minLength: 24)
            }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
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
}
