import SwiftUI

@main
struct SpindleApp: App {
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let startup = Result { try AppModel() }
    @AppStorage(MenuBarSettings.showKey) private var showInMenuBar = true

    var body: some Scene {
        // A single-window app: `Window` (unlike `WindowGroup`) has no "New Window" command,
        // so there is only ever one copy of the player state.
        Window("Spindle", id: Self.mainWindowID) {
            switch startup {
            case .success(let model):
                RootView().appEnvironment(model)
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

        // A mini player in the menu bar, so playback can be controlled with the window closed.
        // Turned off in Settings, or by ⌘-dragging the icon out of the menu bar.
        MenuBarExtra(isInserted: menuBarIsInserted) {
            if case .success(let model) = startup {
                MenuBarPlayer().appEnvironment(model)
            }
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }

    /// Shown only when the library opened (there is nothing to control otherwise) and the user wants it.
    private var menuBarIsInserted: Binding<Bool> {
        Binding(
            get: {
                guard case .success = startup else { return false }
                return showInMenuBar
            },
            set: { showInMenuBar = $0 }
        )
    }
}

private extension View {
    /// Everything the app's views read from the environment.
    func appEnvironment(_ model: AppModel) -> some View {
        environment(model.app)
            .environment(model.library)
            .environment(model.playlists)
            .environment(model.player)
            .environment(model.importer)
            .environment(model.toasts)
            .environment(model.covers)
            .environment(model.equalizer)
            .environment(\.artworkStore, model.artwork)
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
