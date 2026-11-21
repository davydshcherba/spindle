import SwiftUI

/// The window's only chrome: Liquid Glass pills for navigation, tabs, search, Add and settings.
/// It sits above the page, so content never scrolls underneath it. No sidebar.
struct TopBar: View {
    @Environment(AppViewModel.self) private var app
    @Environment(LibraryViewModel.self) private var library
    @State private var isSettingsPresented = false

    /// Space reserved for the traffic-light buttons, which float over the hidden title bar.
    private static let trafficLightInset: CGFloat = 70
    private static let height: CGFloat = 44
    private static let verticalPadding: CGFloat = 8
    /// Distance from the window's top edge to the middle of the pills; the traffic lights line up with it.
    static let centerFromTop = verticalPadding + height / 2

    var body: some View {
        @Bindable var library = library

        // `spacing` is the distance at which glass shapes start to merge; keep it below the
        // gap between the pills so each stays its own shape.
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                Color.clear.frame(width: Self.trafficLightInset, height: 1)

                navigation
                brandAndTabs

                Spacer(minLength: 16)

                SearchField(text: $library.searchText, height: Self.height)
                    .frame(width: 320)

                Button { app.presentAddMusic() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        Text("Add")
                    }
                }
                .buttonStyle(AccentButtonStyle(height: Self.height))
                .keyboardShortcut("o", modifiers: .command)
                .help("Add music (⌘O)")

                IconButton(
                    systemName: "slider.horizontal.3", size: 16, help: "Settings",
                    glass: true, diameter: Self.height
                ) { isSettingsPresented = true }
                .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) { SettingsPopover() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, Self.verticalPadding)
        .onChange(of: library.searchText) { _, text in
            // Searching always happens in My Music.
            if !text.isEmpty, app.route != .myMusic { app.navigate(to: .myMusic) }
        }
    }

    private var navigation: some View {
        HStack(spacing: 0) {
            IconButton(systemName: "chevron.left", size: 14, help: "Back", isEnabled: app.canGoBack) { app.goBack() }
            IconButton(systemName: "chevron.right", size: 14, help: "Forward", isEnabled: app.canGoForward) { app.goForward() }
        }
        .padding(.horizontal, 6)
        .frame(height: Self.height)
        .glassEffect(.regular, in: Capsule())
    }

    private var brandAndTabs: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                VinylDisc().frame(width: 26, height: 26)
                Text("Spindle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 2) {
                tab("My Music", .myMusic)
                tab("Playlists", .playlists)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: Self.height)
        .glassEffect(.regular, in: Capsule())
    }

    private func tab(_ title: String, _ tab: Tab) -> some View {
        let isSelected = app.tab == tab
        return Button {
            app.show(tab)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.muted)
                .padding(.horizontal, 16)
                .frame(height: Self.height - 12)
                .background(isSelected ? Theme.accent : .clear, in: Capsule())
                .animation(Motion.quick, value: isSelected)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SearchField: View {
    @Binding var text: String
    let height: CGFloat
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            TextField("Search songs, albums, artists", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .focused($isFocused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: height)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.accentLight.opacity(isFocused ? 0.8 : 0), lineWidth: 1.5))
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
