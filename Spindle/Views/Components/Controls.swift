import SwiftUI

/// A borderless icon button that brightens on hover.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 17
    var color: Color = Theme.muted
    var hoverColor: Color = Theme.text
    let help: String
    var isEnabled = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(hovering && isEnabled ? hoverColor : color)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// "All / Albums / Artists / Recently added"
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Theme.text.opacity(0.9))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return Theme.accent }
        return hovering ? Theme.surfaceHover : Theme.surface
    }
}

/// The two-segment grid/list switch.
struct LayoutToggle: View {
    @Binding var layout: LibraryViewModel.Layout

    var body: some View {
        HStack(spacing: 2) {
            segment("square.grid.2x2", .grid, help: "Grid view")
            segment("list.bullet", .list, help: "List view")
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func segment(_ symbol: String, _ value: LibraryViewModel.Layout, help: String) -> some View {
        Button { layout = value } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(layout == value ? Color.white : Theme.muted)
                .frame(width: 34, height: 28)
                .background(layout == value ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(layout == value ? .isSelected : [])
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
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
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
