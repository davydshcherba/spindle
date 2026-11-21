import SwiftUI

/// "Edit album": name, album artist, year and cover for every song in the album.
/// Presented by `RootView` for `AppViewModel.albumBeingEdited`.
struct AlbumEditorSheet: View {
    @State private var editor: AlbumEditorViewModel
    private let onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    init(album: Album, library: LibraryViewModel, covers: CoverImporter, onSaved: @escaping (String) -> Void) {
        _editor = State(initialValue: AlbumEditorViewModel(album: album, library: library, covers: covers))
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var editor = editor

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Edit album")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Applies to all \(TimeFormat.count(editor.songCount, "song")) in this album.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            CoverEditor(
                hasCover: editor.hasCover,
                removeTitle: "Remove cover",
                message: editor.coverMessage,
                choose: { Task { await editor.chooseCover() } },
                remove: { editor.removeCover() }
            ) {
                ArtworkView(key: editor.previewKey, pixelSize: 256, cornerRadius: 10)
            }

            VStack(spacing: 12) {
                field("Album name", text: $editor.title, placeholder: "Album name", focused: true)
                field("Album artist", text: $editor.artist, placeholder: UnknownTag.artist)
                field("Year", text: $editor.year, placeholder: "2024")
            }

            if let problem = editor.problem {
                Label(problem.localizedDescription, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xE5776B))
            } else if let notice = editor.mergeNotice {
                Label(notice, systemImage: "arrow.triangle.merge")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accentLight)
            }

            Text("Albums with the same name and album artist are one album. Song files aren\u{2019}t modified.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(AccentButtonStyle(height: 38))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!editor.canSave)
                    .opacity(editor.canSave ? 1 : 0.5)
            }
        }
        .padding(24)
        .sheetContentWidth(480)
        .preferredColorScheme(.dark)
        .onAppear { isTitleFocused = true }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, focused: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            Group {
                if focused {
                    TextField(placeholder, text: text).focused($isTitleFocused)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(Theme.text)
            .onSubmit(save)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.hairline))
        }
    }

    private func save() {
        guard let newID = editor.save() else { return }
        onSaved(newID)
        dismiss()
    }
}
