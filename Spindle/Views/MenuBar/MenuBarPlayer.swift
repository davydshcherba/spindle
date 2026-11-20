import AppKit
import SwiftUI

/// Where the "show Spindle in the menu bar" preference lives. The Settings popover toggles it and
/// the menu bar scene reads it, so music can be controlled from the menu bar with the window closed.
enum MenuBarSettings {
    static let showKey = "showInMenuBar"

    /// On by default, like the `@AppStorage` properties that bind to the same key.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: showKey) as? Bool ?? true
    }
}

/// Closing the window normally quits a single-window app. With the menu bar player on, Spindle
/// keeps running instead, so the music goes on and can be controlled from the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !MenuBarSettings.isEnabled
    }
}

/// The popover that opens from Spindle's menu bar icon: a compact player with the same controls as
/// the player bar, plus shortcuts to bring the main window back or quit.
struct MenuBarPlayer: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(AppViewModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    static let width: CGFloat = 320

    var body: some View {
        VStack(spacing: 14) {
            nowPlaying
            progress
            TransportControls(playSize: 40, iconSize: 16, spacing: 20)
            volume

            Divider().overlay(Theme.hairline)

            footer
        }
        .padding(16)
        .frame(width: Self.width)
        .background { AmbientBackground() }
        .preferredColorScheme(.dark)
        // The main window normally keeps this up to date; it may be closed while music plays.
        .task(id: player.currentItem?.artworkKey) { await player.refreshTint() }
    }

    // MARK: Now playing

    private var nowPlaying: some View {
        HStack(spacing: 12) {
            Button { openSpindle(showingNowPlaying: true) } label: {
                ArtworkView(key: player.currentItem?.artworkKey, pixelSize: 144, cornerRadius: 10)
                    .frame(width: 68, height: 68)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasItem)
            .help("Open Now Playing")
            .accessibilityLabel("Open Now Playing")

            if let item = player.currentItem {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Text(item.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                    Text(item.album)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nothing playing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Pick a song in Spindle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Progress and volume

    private var progress: some View {
        VStack(spacing: 2) {
            SeekBar(
                progress: player.progress,
                isEnabled: player.hasItem,
                accessibilityName: "Playback position",
                onBegan: { player.beginScrub() },
                onChanged: { player.updateScrub($0) },
                onEnded: { player.endScrub(at: $0) }
            )
            HStack {
                Text(player.elapsedText)
                Spacer()
                Text(player.durationText)
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Theme.muted)
        }
    }

    private var volume: some View {
        HStack(spacing: 6) {
            IconButton(systemName: player.volumeSymbol, size: 14, help: player.isMuted ? "Unmute" : "Mute") {
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
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Button { openSpindle(showingNowPlaying: false) } label: {
                Label("Open Spindle", systemImage: "macwindow")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(RowButtonStyle())

            Spacer()

            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(RowButtonStyle())
        }
        .foregroundStyle(Theme.text)
    }

    /// Brings the main window forward (reopening it if it was closed), optionally on Now Playing.
    private func openSpindle(showingNowPlaying: Bool) {
        if showingNowPlaying { app.presentNowPlaying() }
        openWindow(id: SpindleApp.mainWindowID)
        NSApplication.shared.activate()
    }
}

/// The icon in the menu bar.
struct MenuBarLabel: View {
    var body: some View {
        Label("Spindle", systemImage: "music.note")
            .accessibilityLabel("Spindle")
    }
}
