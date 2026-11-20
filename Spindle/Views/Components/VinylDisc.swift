import SwiftUI

/// The Spindle mark: a record with a green label. Scales cleanly from the
/// 26 pt top-bar logo up to the empty-state illustration.
struct VinylDisc: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(Color(hex: 0x0F1012))
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: max(0.5, size * 0.012))
                        .padding(size * (0.1 + 0.075 * Double(ring)))
                }
                Circle()
                    .trim(from: 0.60, to: 0.70)
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: max(0.8, size * 0.028), lineCap: .round))
                    .padding(size * 0.08)
                    .rotationEffect(.degrees(-20))
                Circle().fill(Theme.accent).frame(width: size * 0.36, height: size * 0.36)
                Circle().fill(Color(hex: 0xEEEEEE)).frame(width: size * 0.09, height: size * 0.09)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
