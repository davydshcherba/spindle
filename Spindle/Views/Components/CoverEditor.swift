import SwiftUI

/// The "cover" row of an editor sheet: a preview, "Choose image…", and a way to remove it.
struct CoverEditor<Preview: View>: View {
    let hasCover: Bool
    let removeTitle: String
    let message: String?
    let choose: () -> Void
    let remove: () -> Void
    @ViewBuilder let preview: () -> Preview

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            preview()
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("COVER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)

                Button(action: choose) {
                    Label("Choose image\u{2026}", systemImage: "photo")
                }
                .buttonStyle(OutlineButtonStyle(height: 34))

                if hasCover {
                    Button(removeTitle, action: remove)
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }

                if let message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xE5776B))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
