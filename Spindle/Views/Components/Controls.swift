import SwiftUI

/// A borderless icon button that brightens on hover. With `glass`, it sits on its own
/// Liquid Glass circle (for controls floating over content, not inside another glass slab).
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 17
    var color: Color = Theme.muted
    var hoverColor: Color = Theme.text
    let help: String
    var isEnabled = true
    var glass = false
    /// Overrides the touch target; defaults to the icon size plus padding.
    var diameter: CGFloat?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let side = diameter ?? (size + 16)
        Button(action: action) {
            icon(side: side)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder private func icon(side: CGFloat) -> some View {
        let image = Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(hovering && isEnabled ? hoverColor : color)
            .frame(width: side, height: side)
        if glass {
            image.glassEffect(.regular.interactive(), in: Circle())
        } else {
            image
        }
    }
}

/// "All / Albums / Artists / Recently added"
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.text.opacity(0.92))
                .padding(.horizontal, 18)
                .frame(height: 36)
                .glassSelected(isSelected, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The two-segment grid/list switch.
struct LayoutToggle: View {
    @Binding var layout: LibraryViewModel.Layout

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                segment("square.grid.2x2", .grid, help: "Grid view")
                segment("list.bullet", .list, help: "List view")
            }
        }
    }

    private func segment(_ symbol: String, _ value: LibraryViewModel.Layout, help: String) -> some View {
        let isSelected = layout == value
        return Button { layout = value } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.muted)
                .frame(width: 42, height: 36)
                .glassSelected(isSelected, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Sort: Recently added ⌄" menu pill.
struct SortMenu<Option: Hashable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .medium))
                Text("Sort: ").foregroundStyle(Theme.muted) + Text(selection.rawValue).foregroundStyle(Theme.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Column header label: "TITLE", "ARTIST"…
struct ColumnHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }
}
