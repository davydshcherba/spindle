import SwiftUI

/// "Edit info" for one song. Presented by `RootView` for `AppViewModel.trackBeingEdited`.
struct TrackEditorSheet: View {
    @State private var editor: TrackEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field: Hashable { case title, artist, album, albumArtist, year, track }

    init(track: Track, library: LibraryViewModel, covers: CoverImporter) {
        _editor = State(initialValue: TrackEditorViewModel(track: track, library: library, covers: covers))
    }

    var body: some View {
        @Bindable var editor = editor

        VStack(alignment: .leading, spacing: 18) {
            header

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
                field("Title", text: $editor.title, placeholder: "Song title", id: .title)
                field("Artist", text: $editor.artist, placeholder: UnknownTag.artist, id: .artist)
                field("Album", text: $editor.album, placeholder: UnknownTag.album, id: .album)
                field("Album artist", text: $editor.albumArtist, placeholder: "Same as artist", id: .albumArtist)
                HStack(spacing: 12) {
                    field("Year", text: $editor.year, placeholder: "2024", id: .year)
                    field("Track number", text: $editor.trackNumber, placeholder: "1", id: .track)
                }
            }

            if let problem = editor.problem {
                Label(problem.localizedDescription, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xE5776B))
            }

            Text("Changes, including the cover, are saved in Spindle only. The file on disk isn\u{2019}t modified.")
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
        .frame(width: 480)
        .preferredColorScheme(.dark)
        .onAppear { focus = .title }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Edit info")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(editor.fileName)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(editor.fileSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, id: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($focus, equals: id)
                .onSubmit(save)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(focus == id ? Theme.accent : Theme.hairline)
                )
        }
    }

    private func save() {
        if editor.save() { dismiss() }
    }
}
