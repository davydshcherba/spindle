import SwiftUI

/// Shown when a detail page's playlist/album/artist no longer exists.
struct MissingItemView: View {
    let message: String
    let backTitle: String
    let back: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.muted)
            Text(message)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
            Button("Back to \(backTitle)", action: back)
                .buttonStyle(OutlineButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
