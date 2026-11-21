import SwiftUI

/// Shown while songs are being added: what's happening, how far along, and when it's done.
struct PhoneImportSheet: View {
    @Environment(ImportViewModel.self) private var importer

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            if let session = importer.session {
                progress(for: session)
            } else {
                Text("Nothing to add")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }

            Spacer(minLength: 0)

            if importer.isImporting {
                Button("Cancel import") { importer.cancel() }
                    .buttonStyle(OutlineButtonStyle(height: 50))
            } else {
                Button(importer.session == nil ? "Close" : "Done") { importer.close() }
                    .buttonStyle(AccentButtonStyle(height: 50))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(importer.isImporting)
        .preferredColorScheme(.dark)
    }

    private func progress(for session: ImportSession) -> some View {
        VStack(spacing: 14) {
            Image(systemName: session.isFinished ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.system(size: 44))
                .foregroundStyle(session.isFinished ? Theme.accentLight : Theme.muted)
                .contentTransition(.symbolEffect(.replace))

            Text(headline(for: session))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            ProgressView(value: session.fractionCompleted)
                .tint(Theme.accent)
                .padding(.horizontal, 12)

            Text(session.isFinished ? importer.resultText : importer.progressText)
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .animation(Motion.quick, value: session.isFinished)
    }

    private func headline(for session: ImportSession) -> String {
        switch session.phase {
        case .scanning: "Looking for music\u{2026}"
        case .importing: "Adding your songs"
        case .finished: session.isCancelled ? "Import cancelled" : "Import complete"
        }
    }
}
