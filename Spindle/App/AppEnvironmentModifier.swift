import SwiftUI

extension View {
    /// Everything the app's views read from the environment. Shared by the Mac and iPhone apps.
    func appEnvironment(_ model: AppModel) -> some View {
        environment(model.app)
            .environment(model.library)
            .environment(model.playlists)
            .environment(model.player)
            .environment(model.importer)
            .environment(model.toasts)
            .environment(model.covers)
            .environment(model.equalizer)
            .environment(\.artworkStore, model.artwork)
    }
}
