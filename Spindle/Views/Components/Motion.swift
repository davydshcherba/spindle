import SwiftUI

/// Spindle's motion vocabulary. Everything entering or changing uses a strong ease-out (it arrives
/// fast and settles; ease-in would delay the very moment a person is watching), and nothing that is
/// seen over and over runs much past 300 ms.
enum Motion {
    static func out(_ duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }

    /// Hover, press, colour and icon changes: felt more than watched.
    static let quick = out(0.15)
    /// Something fading in place, such as a cover that has just been decoded.
    static let fade = out(0.2)
    /// Content replaced in place: the cover and the title when the track changes.
    static let swap = out(0.28)
}

/// Replaces its content in place whenever `id` changes, instead of letting it teleport.
///
/// - `.cover`: the new picture settles in on top (a touch smaller, fading in) while the old one stays
///   put until it is covered, so the crossfade never dips through the background.
/// - `.text`: the old text leaves quickly and the new text rises into place from a few points below.
///
/// Reduced motion keeps the fade and drops the scale and the movement. Interruptible: skipping
/// through tracks quickly just stacks fades, and each layer finishes on its own.
struct Swap<ID: Hashable, Content: View>: View {
    enum Style { case cover, text }

    let id: ID
    var style: Style
    var alignment: Alignment
    /// Offsets pieces that change together (title, then artist) by a few tens of milliseconds.
    var delay: Double
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        id: ID,
        style: Style = .text,
        alignment: Alignment = .center,
        delay: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.style = style
        self.alignment = alignment
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: alignment) {
            content
                .id(id)
                .transition(transition)
        }
        .animation(Motion.swap, value: id)
    }

    private var transition: AnyTransition {
        switch style {
        case .cover:
            let rise = reduceMotion ? AnyTransition.identity : .scale(scale: 0.96)
            return .asymmetric(
                insertion: AnyTransition.opacity.combined(with: rise).animation(Motion.swap.delay(delay)),
                removal: AnyTransition.opacity.animation(Motion.out(0.12).delay(0.2 + delay))
            )
        case .text:
            let rise = reduceMotion ? AnyTransition.identity : .offset(y: 6)
            return .asymmetric(
                insertion: AnyTransition.opacity.combined(with: rise).animation(Motion.swap.delay(delay)),
                removal: AnyTransition.opacity.animation(Motion.out(0.12))
            )
        }
    }
}
