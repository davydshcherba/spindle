import SwiftUI

extension View {
    /// The width of a sheet's (or popover's) content. On the Mac it is fixed; on the phone it
    /// fills the screen and scrolls when the content is taller than the sheet.
    @ViewBuilder func sheetContentWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width)
        #else
        ScrollView {
            frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        #endif
    }
}
