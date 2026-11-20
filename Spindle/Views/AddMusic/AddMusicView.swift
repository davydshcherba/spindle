import SwiftUI

/// The "Add music" dialog: drop zone, file/folder buttons and live import progress.
struct AddMusicView: View {
    @Environment(ImportViewModel.self) private var importer

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { importer.close() }

            VStack(alignment: .leading, spacing: 22) {
                header
                dropZone
                if let session = importer.session {
                    ProgressSection(session: session)
                }
                footer
            }
            .padding(28)
            .frame(width: 700)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 18)
        }
        .onExitCommand { importer.close() }
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add music")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("MP3, M4A, FLAC and WAV files. Folders are scanned with all subfolders.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(systemName: "xmark", size: 14, help: "Close") { importer.close() }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.accentLight)
                .frame(width: 62, height: 62)
                .background(Theme.accent.opacity(0.28), in: Circle())

            Text("Drop files or choose a folder")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)

            HStack(spacing: 10) {
                Button {
                    Task { await importer.chooseFiles() }
                } label: {
                    Label("Choose files", systemImage: "doc")
                }
                .buttonStyle(OutlineSquareButtonStyle())

                Button {
                    Task { await importer.chooseFolder() }
                } label: {
                    Label("Choose folder", systemImage: "folder")
                }
                .buttonStyle(AccentButtonStyle(height: 40, cornerRadius: 9))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .background(
            (importer.isDropTargeted ? Theme.accent.opacity(0.14) : Color.clear),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    importer.isDropTargeted ? Theme.accentLight : Color.white.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
        )
    }

    private var footer: some View {
        @Bindable var importer = importer
        return HStack(spacing: 14) {
            Toggle("Skip duplicates", isOn: $importer.skipDuplicates)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
                .fixedSize()

            Spacer()

            if importer.isImporting {
                Button("Cancel import") { importer.cancel() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Button("Continue in background") { importer.close() }
                    .buttonStyle(LightButtonStyle())
            } else {
                Button(importer.session == nil ? "Close" : "Done") { importer.close() }
                    .buttonStyle(LightButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - Progress

private struct ProgressSection: View {
    @Environment(ImportViewModel.self) private var importer
    let session: ImportSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(Theme.hairline)

            HStack(alignment: .firstTextBaseline) {
                title
                Spacer()
                Text(session.isFinished ? importer.resultText : importer.progressText)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }

            ProgressView(value: session.fractionCompleted)
                .progressViewStyle(.linear)
                .tint(Theme.accent)

            VStack(spacing: 4) {
                ForEach(session.visibleEntries) { entry in
                    EntryRow(entry: entry)
                }
            }
            .frame(minHeight: 4 * 44, alignment: .top)
        }
    }

    @ViewBuilder private var title: some View {
        switch session.phase {
        case .scanning:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Scanning \(session.sourceName)\u{2026}").foregroundStyle(Theme.text)
            }
            .font(.system(size: 15, weight: .semibold))
        case .importing:
            (Text("Importing ").fontWeight(.semibold) + Text("from ").foregroundStyle(Theme.muted) + Text(session.sourceName).fontWeight(.semibold))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
        case .finished:
            Text(session.isCancelled ? "Import cancelled" : "Import complete")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
    }
}

private struct EntryRow: View {
    let entry: ImportSession.Entry

    var body: some View {
        HStack(spacing: 12) {
            icon.frame(width: 24, height: 24)
            Text(entry.name)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            status
        }
        .frame(height: 40)
    }

    @ViewBuilder private var icon: some View {
        switch entry.status {
        case .added:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.accentLight)
                .frame(width: 24, height: 24)
                .background(Theme.accent.opacity(0.45), in: Circle())
        case .reading:
            ProgressView().controlSize(.small)
        case .waiting:
            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
        case .skipped:
            Image(systemName: "arrow.uturn.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.08), in: Circle())
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0xE5776B))
                .frame(width: 24, height: 24)
                .background(Color(hex: 0xE5776B).opacity(0.2), in: Circle())
        }
    }

    @ViewBuilder private var status: some View {
        switch entry.status {
        case .added: Text("Added").foregroundStyle(Theme.accentLight)
        case .reading: Text("Reading tags\u{2026}").foregroundStyle(Theme.muted)
        case .waiting: Text("Waiting").foregroundStyle(Theme.muted)
        case .skipped: Text("Already in library").foregroundStyle(Theme.muted)
        case .failed(let reason): Text(reason).foregroundStyle(Color(hex: 0xE5776B)).lineLimit(1)
        }
    }
}

// MARK: - Button styles

private struct OutlineSquareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.3)))
    }
}

private struct LightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(hex: 0x222831))
            .padding(.horizontal, 20)
            .frame(height: 42)
            .background(
                Color(hex: 0xEEEEEE).opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}
