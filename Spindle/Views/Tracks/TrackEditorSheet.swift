import SwiftUI

/// "Edit info" for one song. Presented by `RootView` for `AppViewModel.trackBeingEdited`.
struct TrackEditorSheet: View {
    @State private var editor: TrackEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    /// The list of existing albums under the Album field.
    @State private var isAlbumListOpen = false
    /// Opened with the arrow button: every album, however little is typed.
    @State private var albumListShowsAll = false
    @State private var highlightedAlbum: Int?
    /// The text a chosen album put in the field, so setting it doesn't count as typing.
    @State private var textFromChoice: String?

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
                albumField(text: $editor.album)
                field("Album artist", text: $editor.albumArtist, placeholder: "Same as artist", id: .albumArtist)
                HStack(spacing: 12) {
                    field("Year", text: $editor.year, placeholder: "2024", id: .year)
                    field("Track number", text: $editor.trackNumber, placeholder: "1", id: .track)
                }
            }
            // Above the note and the buttons below, so the album list covers them, not the reverse.
            .zIndex(1)

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
        .sheetContentWidth(480)
        .preferredColorScheme(.dark)
        .onAppear { focus = .title }
        // Typing in the Album field suggests the albums that match.
        .onChange(of: editor.album) { _, text in
            if text == textFromChoice { return }
            textFromChoice = nil
            guard focus == .album else { return }
            albumListShowsAll = false
            highlightedAlbum = nil
            isAlbumListOpen = !albumChoices.isEmpty
        }
        .onChange(of: focus) { _, field in
            if let field, field != .album { isAlbumListOpen = false }
        }
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

    // MARK: Fields

    private func fieldLabel(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }

    /// The recessed box around a field; it lights up while the field has focus.
    private func box<Content: View>(_ id: Field, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focus == id ? Theme.accent : Theme.hairline)
            )
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, id: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            box(id) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .focused($focus, equals: id)
                    .onSubmit(save)
            }
        }
    }

    // MARK: Album

    /// Existing albums to offer: those matching the typed text, or all of them.
    private var albumChoices: [TrackEditorViewModel.AlbumChoice] {
        editor.albumChoices(filteredByTyping: !albumListShowsAll)
    }

    /// Type to name an album (new or existing), or pick one that exists: the song then gets that
    /// album's title and artist together.
    private func albumField(text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Album")
            box(.album) {
                HStack(spacing: 8) {
                    TextField(UnknownTag.album, text: text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.text)
                        .focused($focus, equals: .album)
                        .onSubmit(submitAlbum)
                        .onKeyPress(.downArrow) { moveHighlight(by: 1) }
                        .onKeyPress(.upArrow) { moveHighlight(by: -1) }
                        .onKeyPress(.escape) { closeAlbumList() }
                    Button(action: toggleAlbumList) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .rotationEffect(.degrees(isAlbumListOpen ? 180 : 0))
                            .animation(Motion.quick, value: isAlbumListOpen)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Choose an album you already have")
                    .accessibilityLabel("Choose an existing album")
                }
            }
            .overlay(alignment: .topLeading) {
                if isAlbumListOpen {
                    AlbumDropdown(
                        choices: albumChoices, selectedID: selectedAlbumID, highlighted: highlightedAlbum,
                        select: choose
                    )
                    .offset(y: 44)
                    .transition(.opacity)
                }
            }
            .animation(Motion.quick, value: isAlbumListOpen)

            // Hidden while the list covers it, but it keeps its room so the fields don't jump.
            albumOutcomeHint
                .opacity(isAlbumListOpen ? 0 : 1)
                .allowsHitTesting(false)
        }
        // Above the fields below it, so the list covers them instead of sliding underneath.
        .zIndex(1)
    }

    private var selectedAlbumID: String? {
        switch editor.albumOutcome {
        case .stays(let choice), .joins(let choice): choice.id
        case .creates: nil
        }
    }

    /// One line saying what saving does: stay, join an album that exists, or make a new one.
    private var albumOutcomeHint: some View {
        let hint: (symbol: String, text: String, isNotable: Bool) = switch editor.albumOutcome {
        case .stays(let choice):
            ("square.stack", "In \u{201C}\(choice.title)\u{201D} by \(choice.artist)", false)
        case .joins(let choice):
            ("arrow.right.circle.fill", "Adds to \u{201C}\(choice.title)\u{201D} by \(choice.detail)", true)
        case .creates(let title, let artist):
            ("plus.circle.fill", "New album \u{201C}\(title)\u{201D} by \(artist)", true)
        }
        return Label(hint.text, systemImage: hint.symbol)
            .font(.system(size: 12))
            .foregroundStyle(hint.isNotable ? Theme.accentLight : Theme.muted)
            .lineLimit(1)
            .truncationMode(.tail)
            .animation(Motion.quick, value: hint.text)
    }

    private func toggleAlbumList() {
        if isAlbumListOpen {
            isAlbumListOpen = false
        } else {
            albumListShowsAll = true
            highlightedAlbum = nil
            focus = .album
            isAlbumListOpen = true
        }
    }

    private func closeAlbumList() -> KeyPress.Result {
        guard isAlbumListOpen else { return .ignored }
        isAlbumListOpen = false
        return .handled
    }

    private func moveHighlight(by step: Int) -> KeyPress.Result {
        let choices = albumChoices
        guard !choices.isEmpty else { return .ignored }
        guard isAlbumListOpen else {
            highlightedAlbum = step > 0 ? 0 : choices.count - 1
            isAlbumListOpen = true
            return .handled
        }
        let start = highlightedAlbum ?? (step > 0 ? -1 : choices.count)
        highlightedAlbum = min(choices.count - 1, max(0, start + step))
        return .handled
    }

    private func choose(_ choice: TrackEditorViewModel.AlbumChoice) {
        editor.choose(choice)
        textFromChoice = editor.album
        isAlbumListOpen = false
        highlightedAlbum = nil
        focus = .album
    }

    /// Return picks the highlighted album if the arrow keys landed on one; otherwise it saves.
    private func submitAlbum() {
        let choices = albumChoices
        if isAlbumListOpen, let index = highlightedAlbum, choices.indices.contains(index) {
            choose(choices[index])
        } else {
            save()
        }
    }

    private func save() {
        if editor.save() { dismiss() }
    }
}

/// The albums that already exist, under the Album field: cover, title, artist and size.
private struct AlbumDropdown: View {
    let choices: [TrackEditorViewModel.AlbumChoice]
    let selectedID: String?
    let highlighted: Int?
    let select: (TrackEditorViewModel.AlbumChoice) -> Void

    private static let rowHeight: CGFloat = 48
    private static let rowSpacing: CGFloat = 2
    private static let maxVisibleRows = 5

    var body: some View {
        let rows = min(choices.count, Self.maxVisibleRows)
        let height = CGFloat(rows) * (Self.rowHeight + Self.rowSpacing) + 10

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Self.rowSpacing) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        AlbumDropdownRow(
                            choice: choice, isSelected: choice.id == selectedID, isHighlighted: index == highlighted
                        ) { select(choice) }
                        .frame(height: Self.rowHeight)
                    }
                }
                .padding(5)
            }
            .onChange(of: highlighted) { _, index in
                if let index, choices.indices.contains(index) { proxy.scrollTo(choices[index].id) }
            }
        }
        .frame(height: height)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
    }
}

private struct AlbumDropdownRow: View {
    let choice: TrackEditorViewModel.AlbumChoice
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ArtworkView(key: choice.artworkKey, pixelSize: 64, cornerRadius: 5)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(choice.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accentLight)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .background(
                isHighlighted || isHovering ? Color.white.opacity(0.09) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("\(choice.title), \(choice.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
