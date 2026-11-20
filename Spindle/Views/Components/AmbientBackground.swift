import SwiftUI

/// The window's backdrop. Liquid Glass needs something to refract, so instead of a flat
/// colour this is the dark base with soft pools of light: the accent green top-left and the
/// colour of the cover that's playing bottom-right, which fades as tracks change.
struct AmbientBackground: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        let tint = player.tint.map(Color.init) ?? Theme.accent
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.accent.opacity(0.30), .clear],
                center: .topLeading, startRadius: 0, endRadius: 760
            )
            RadialGradient(
                colors: [tint.opacity(player.hasItem ? 0.38 : 0.16), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 900
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.9), value: player.tint)
        .accessibilityHidden(true)
    }
}
