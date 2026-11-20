import SwiftUI

/// The window's only chrome: navigation, tabs, search, Add and settings. No sidebar.
struct TopBar: View {
    @Environment(AppViewModel.self) private var app
    @Environment(LibraryViewModel.self) private var library
    @State private var isSettingsPresented = false

    /// Space reserved for the traffic-light buttons, which float over the hidden title bar.
    private static let trafficLightInset: CGFloat = 78

    var body: some View {
        @Bindable var library = library

        HStack(spacing: 14) {
            HStack(spacing: 0) {
                IconButton(systemName: "chevron.left", size: 14, help: "Back", isEnabled: app.canGoBack) { app.goBack() }
                IconButton(systemName: "chevron.right", size: 14, help: "Forward", isEnabled: app.canGoForward) { app.goForward() }
            }
            .padding(.leading, Self.trafficLightInset)

            brand
            tabs

            Spacer(minLength: 16)

            SearchField(text: $library.searchText)

            Button { app.presentAddMusic() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("Add")
                }
            }
            .buttonStyle(AccentButtonStyle(height: 36))
            .keyboardShortcut("o", modifiers: .command)
            .help("Add music (⌘O)")

            IconButton(systemName: "slider.horizontal.3", size: 17, help: "Settings") { isSettingsPresented = true }
                .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) { SettingsPopover() }
        }
        .padding(.trailing, 20)
        .frame(height: 62)
        .background(Theme.surface)
        .onChange(of: library.searchText) { _, text in
            // Searching always happens in My Music.
            if !text.isEmpty, app.route != .myMusic { app.navigate(to: .myMusic) }
        }
    }

    private var brand: some View {
        HStack(spacing: 9) {
            VinylDisc().frame(width: 28, height: 28)
            Text("Spindle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
        .accessibilityElement(children: .combine)
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            tab("My Music", .myMusic)
            tab("Playlists", .playlists)
        }
        .padding(3)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .frame(height: 30)
                .background(isSelected ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SearchField: View {
    @Binding var text: String
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
        .padding(.horizontal, 12)
        .frame(width: 330, height: 36)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isFocused ? Theme.accent : Theme.hairline, lineWidth: 1)
        )
    }
}
