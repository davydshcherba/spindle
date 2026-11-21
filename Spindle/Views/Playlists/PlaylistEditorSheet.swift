import SwiftUI

/// Create a playlist, or edit one's name and cover picture. Presented by `RootView` for
/// `AppViewModel.playlistEditor`.
struct PlaylistEditorSheet: View {
    @State private var editor: PlaylistEditorViewModel
    private let onCreated: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    init(
        editor: PlaylistEditor, playlists: PlaylistsViewModel, covers: CoverImporter,
        onCreated: @escaping (UUID) -> Void
    ) {
        let mode: PlaylistEditorViewModel.Mode = switch editor {
        case .create(let tracks): .create(adding: tracks)
        case .edit(let id): .edit(id)
        }
        _editor = State(initialValue: PlaylistEditorViewModel(mode: mode, playlists: playlists, covers: covers))
        self.onCreated = onCreated
    }

    var body: some View {
        @Bindable var editor = editor

        VStack(alignment: .leading, spacing: 18) {
            Text(editor.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            if !editor.isCreating {
                CoverEditor(
                    hasCover: editor.hasCustomCover,
                    removeTitle: "Use automatic cover",
                    message: editor.coverMessage,
                    choose: { Task { await editor.chooseCover() } },
                    remove: { editor.useAutomaticCover() }
                ) {
                    PlaylistMosaic(keys: editor.previewKeys, pixelSize: 256, cornerRadius: 10)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                TextField(editor.isCreating ? "New Playlist" : "Playlist name", text: $editor.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .focused($isFocused)
                    .onSubmit(save)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isFocused ? Theme.accent : Theme.hairline)
                    )
            }

            if !editor.isCreating {
                Text("Without a picture, the cover is a mosaic of the songs inside.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)
                Button(editor.isCreating ? "Create" : "Save", action: save)
                    .buttonStyle(AccentButtonStyle(height: 38))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.canSave)
                    .opacity(editor.canSave ? 1 : 0.5)
            }
        }
        .padding(24)
        .sheetContentWidth(440)
        .preferredColorScheme(.dark)
        .onAppear { isFocused = true }
    }

    private func save() {
        guard editor.canSave else { return }
        // Made from the Playlists page (no tracks to add): open it so songs can be added.
        if let created = editor.save() { onCreated(created) }
        dismiss()
    }
}
