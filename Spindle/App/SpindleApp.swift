import SwiftUI

@main
struct SpindleApp: App {
    private let startup = Result { try AppModel() }

    var body: some Scene {
        // A single-window app: `Window` (unlike `WindowGroup`) has no "New Window" command,
        // so there is only ever one copy of the player state.
        Window("Spindle", id: "main") {
            switch startup {
            case .success(let model):
                RootView()
                    .environment(model.app)
                    .environment(model.library)
                    .environment(model.playlists)
                    .environment(model.player)
                    .environment(model.importer)
                    .environment(model.toasts)
                    .environment(model.covers)
                    .environment(\.artworkStore, model.artwork)
            case .failure(let error):
                StartupErrorView(error: error)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 820)
        .commands {
            if case .success(let model) = startup {
                PlaybackCommands(model: model)
            }
        }
    }
}

/// Keyboard-driven playback, in the standard places for a Mac music player.
struct PlaybackCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Playback") {
            Button(model.player.isPlaying ? "Pause" : "Play") { model.player.togglePlayPause() }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!model.player.hasItem)
            Button("Next") { model.player.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!model.player.hasItem)
            Button("Previous") { model.player.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!model.player.hasItem)
            Divider()
            Button("Shuffle") { model.player.toggleShuffle() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Repeat") { model.player.cycleRepeat() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            Divider()
            Button("Volume Up") { model.player.volume += 0.1 }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Volume Down") { model.player.volume -= 0.1 }
                .keyboardShortcut(.downArrow, modifiers: .command)
        }
    }
}

private struct StartupErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Theme.muted)
            Text("Spindle couldn\u{2019}t open your library")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Text("Your music files are untouched.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(40)
        .frame(minWidth: 520, minHeight: 320)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
