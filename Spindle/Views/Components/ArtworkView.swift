import SwiftUI

extension EnvironmentValues {
    @Entry var artworkStore: ArtworkStore?
}

/// Square cover art. Shows already-decoded art immediately and decodes the rest
/// off the main actor, so scrolling a big grid never waits on the disk.
struct ArtworkView: View {
    let key: String?
    var pixelSize = 256
    var cornerRadius: CGFloat = 8

    @Environment(\.artworkStore) private var store
    @State private var loaded: CGImage?

    var body: some View {
        let image = loaded ?? key.flatMap { store?.cachedImage(forKey: $0, maxPixelSize: pixelSize) }
        Color.clear
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    ArtworkPlaceholder()
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: key) { await load() }
            .accessibilityHidden(true)
    }

    private func load() async {
        guard let key, let store else {
            loaded = nil
            return
        }
        if store.cachedImage(forKey: key, maxPixelSize: pixelSize) != nil {
            loaded = nil // the cached copy is picked up in `body`
            return
        }
        loaded = nil
        loaded = await store.loadImage(forKey: key, maxPixelSize: pixelSize)
    }
}

struct ArtworkPlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x2E3340), Color(hex: 0x262A33)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * 0.34)
                    .foregroundStyle(Theme.muted.opacity(0.7))
            }
        }
    }
}

/// The 2×2 cover mosaic used for playlists. One cover fills the square; two or
/// three repeat so the mosaic never has holes.
struct PlaylistMosaic: View {
    let keys: [String]
    var pixelSize = 256
    var cornerRadius: CGFloat = 10

    var body: some View {
        Color.clear
            .overlay {
                switch keys.count {
                case 0:
                    ArtworkPlaceholder()
                case 1:
                    ArtworkView(key: keys[0], pixelSize: pixelSize * 2, cornerRadius: 0)
                default:
                    VStack(spacing: 0) {
                        HStack(spacing: 0) { tile(0); tile(1) }
                        HStack(spacing: 0) { tile(2); tile(3) }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    private func tile(_ index: Int) -> some View {
        ArtworkView(key: keys[index % keys.count], pixelSize: pixelSize, cornerRadius: 0)
    }
}
