import SwiftUI

/// Create or rename a playlist. Presented by `RootView` for `AppViewModel.playlistEditor`.
struct PlaylistNameSheet: View {
    let editor: PlaylistEditor

    @Environment(\.dismiss) private var dismiss
    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(AppViewModel.self) private var app
    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var isCreating: Bool {
        if case .create = editor { return true }
        return false
    }

    private var canCommit: Bool {
        isCreating || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isCreating ? "New playlist" : "Rename playlist")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            TextField(isCreating ? "New Playlist" : "Playlist name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($isFocused)
                .onSubmit(commit)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isFocused ? Theme.accent : Theme.hairline))

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)
                Button(isCreating ? "Create" : "Save", action: commit)
                    .buttonStyle(AccentButtonStyle(height: 38))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCommit)
                    .opacity(canCommit ? 1 : 0.5)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
        .onAppear {
            if case .rename(let id) = editor { name = playlists.summary(for: id)?.name ?? "" }
            isFocused = true
        }
    }

    private func commit() {
        guard canCommit else { return }
        switch editor {
        case .create(let tracks):
            let playlist = playlists.create(named: name, adding: tracks)
            // Made from the Playlists page (no tracks to add): open it so songs can be added.
            if tracks.isEmpty { app.navigate(to: .playlist(playlist.id)) }
        case .rename(let id):
            playlists.rename(id, to: name)
        }
        dismiss()
    }
}
