import SwiftUI

@main
struct SpindleiOSApp: App {
    private let startup = Result { try AppModel() }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let model):
                PhoneRootView()
                    .appEnvironment(model)
                    // "Open in Spindle" from Files, Safari or the share sheet. Several songs arrive
                    // as several calls; the import queues them one batch after another.
                    .onOpenURL { url in _ = model.importer.handleDrop([url]) }
            case .failure(let error):
                PhoneStartupErrorView(error: error)
            }
        }
    }
}

private struct PhoneStartupErrorView: View {
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
            Text("Your music files are untouched.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}
