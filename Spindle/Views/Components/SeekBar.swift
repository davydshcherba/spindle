import SwiftUI

/// A thin progress/volume bar with a round thumb. Used for track position and volume.
/// Drag anywhere on it; the callbacks report a 0…1 fraction.
struct SeekBar: View {
    var progress: Double
    var thickness: CGFloat = 4
    var thumbSize: CGFloat = 14
    var fill: Color = Theme.accent
    var track: Color = Color.white.opacity(0.2)
    var isEnabled = true
    var accessibilityName = "Progress"
    var onBegan: () -> Void = {}
    var onChanged: (Double) -> Void = { _ in }
    var onEnded: (Double) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let fraction = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule().fill(track).frame(height: thickness)
                Capsule().fill(fill).frame(width: width * fraction, height: thickness)
                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .offset(x: min(max(0, width * fraction - thumbSize / 2), width - thumbSize))
                    .opacity(isEnabled ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isDragging {
                            isDragging = true
                            onBegan()
                        }
                        onChanged(clamp(value.location.x / width))
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        isDragging = false
                        onEnded(clamp(value.location.x / width))
                    }
            )
            .animation(.easeOut(duration: 0.12), value: isDragging)
        }
        .frame(height: max(thumbSize, 20))
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: onEnded(clamp(progress + 0.05))
            case .decrement: onEnded(clamp(progress - 0.05))
            @unknown default: break
            }
        }
    }

    private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}
