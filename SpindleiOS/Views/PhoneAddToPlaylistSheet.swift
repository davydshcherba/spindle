import SwiftUI

/// Pick a playlist for some songs, or start a new one with them.
struct PhoneAddToPlaylistSheet: View {
    let tracks: [Track]

    @Environment(PlaylistsViewModel.self) private var playlists
    @Environment(CoverImporter.self) private var covers
    @Environment(\.dismiss) private var dismiss
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            List {
                Button { isCreating = true } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.accentLight.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 48, height: 48)
                            .overlay(Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.accentLight))
                        Text("New playlist")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accentLight)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)

                ForEach(playlists.summaries) { summary in
                    row(summary).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .sheet(isPresented: $isCreating) {
            PlaylistEditorSheet(editor: .create(adding: tracks.map(\.id)), playlists: playlists, covers: covers) { _ in
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private func row(_ summary: PlaylistsViewModel.Summary) -> some View {
        let alreadyIn = tracks.count == 1 && summary.playlist.trackIDs.contains(tracks[0].id)
        return Button {
            playlists.add(tracks, to: summary.playlist)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                PlaylistMosaic(keys: summary.artworkKeys, pixelSize: 128, cornerRadius: 8)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(summary.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                if alreadyIn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accentLight)
                        .accessibilityLabel("Already added")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
