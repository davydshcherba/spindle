import SwiftUI

struct SettingsPopover: View {
    @Environment(LibraryViewModel.self) private var library
    @AppStorage(MenuBarSettings.showKey) private var showInMenuBar = true
    @State private var isConfirmingRemoval = false
    @State private var isConfirmingOneAlbum = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "Spindle \(version)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(library.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            Divider().overlay(Theme.hairline)

            Toggle(isOn: $showInMenuBar) {
                Label("Show in menu bar", systemImage: "menubar.rectangle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
            .toggleStyle(.switch)
            .tint(Theme.accent)

            Divider().overlay(Theme.hairline)

            Button {
                isConfirmingOneAlbum = true
            } label: {
                Label("Put all songs in one album\u{2026}", systemImage: "rectangle.stack")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)
            .disabled(library.isLibraryEmpty)

            Button(role: .destructive) {
                isConfirmingRemoval = true
            } label: {
                Label("Remove all music\u{2026}", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(hex: 0xE5776B))
            .disabled(library.isLibraryEmpty)

            Divider().overlay(Theme.hairline)

            Text("\(versionText) \u{00B7} dark theme only for now")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
        .padding(18)
        .frame(width: 280, alignment: .leading)
        .confirmationDialog(
            "Put all songs in \u{201C}\(LibraryDefaults.songsAlbum)\u{201D}?",
            isPresented: $isConfirmingOneAlbum, titleVisibility: .visible
        ) {
            Button("Put All in One Album") { library.putAllSongsInOneAlbum() }
        } message: {
            Text("Every song moves into one album. Artist names, files and playlists don\u{2019}t change. You can still edit any song or album afterwards.")
        }
        .confirmationDialog("Remove all music from Spindle?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove All Music", role: .destructive) { library.removeAllMusic() }
        } message: {
            Text("Your files on disk are not touched. Playlists are kept but become empty.")
        }
    }
}
