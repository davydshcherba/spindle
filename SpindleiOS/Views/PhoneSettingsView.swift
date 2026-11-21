import SwiftUI

/// Library housekeeping: how big it is, the one-album shortcut, and starting over.
struct PhoneSettingsView: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemoval = false
    @State private var isConfirmingOneAlbum = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
        return "Spindle \(version)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Library") {
                    Text(library.summary)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button { isConfirmingOneAlbum = true } label: {
                        Label("Put all songs in one album\u{2026}", systemImage: "rectangle.stack")
                            .foregroundStyle(Theme.text)
                    }
                    .disabled(library.isLibraryEmpty)
                    .listRowBackground(Color.clear)

                    Button(role: .destructive) { isConfirmingRemoval = true } label: {
                        Label("Remove all music\u{2026}", systemImage: "trash")
                            .foregroundStyle(Color(hex: 0xE5776B))
                    }
                    .disabled(library.isLibraryEmpty)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Text("\(versionText) \u{00B7} dark theme only for now")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(
                "Put all songs in \u{201C}\(LibraryDefaults.songsAlbum)\u{201D}?",
                isPresented: $isConfirmingOneAlbum, titleVisibility: .visible
            ) {
                Button("Put All in One Album") { library.putAllSongsInOneAlbum() }
            } message: {
                Text("Every song moves into one album. Artist names, files and playlists don\u{2019}t change. You can still edit any song or album afterwards.")
            }
            .confirmationDialog("Remove all music from Spindle?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("Remove All Music", role: .destructive) {
                    library.removeAllMusic()
                    dismiss()
                }
            } message: {
                Text("Spindle\u{2019}s copies of the songs are deleted. The original files you added are not touched. Playlists are kept but become empty.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
