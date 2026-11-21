import AppKit
import SwiftUI

/// Lines the window's traffic-light buttons up with the middle of the top bar.
///
/// The title bar is hidden, so the buttons stay at the system's default height, which sits above
/// the centre of the bar's pills. Put this in a view's `.background`.
struct TrafficLightAlignment: NSViewRepresentable {
    /// Distance from the top edge of the window to the line the buttons' centres should sit on.
    let centerFromTop: CGFloat

    func makeNSView(context: Context) -> Anchor { Anchor() }

    func updateNSView(_ view: Anchor, context: Context) {
        view.centerFromTop = centerFromTop
        view.align()
    }

    final class Anchor: NSView {
        var centerFromTop: CGFloat = 0
        private var observers: [any NSObjectProtocol] = []
        private weak var observedContainer: NSView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            observedContainer = nil
            guard let window else { return }
            // AppKit puts the buttons back where it wants them when the window re-lays out.
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didBecomeKeyNotification,
            ]
            observers = names.map { name in observe(name, object: window) }
            align()
        }

        private func observe(_ name: Notification.Name, object: Any) -> any NSObjectProtocol {
            NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.align() }
            }
        }

        /// Safe to call at any time: it only touches what is out of place, so it never loops.
        func align() {
            guard let window,
                  !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let titlebar = close.superview,
                  let container = titlebar.superview,
                  let themeFrame = container.superview
            else { return }

            // AppKit centres the buttons in the title bar, so make the bar twice as tall as the
            // distance from the window's top edge to the line they should sit on.
            let height = (centerFromTop * 2).rounded()
            let wanted = NSRect(x: container.frame.minX, y: themeFrame.bounds.height - height,
                                width: container.frame.width, height: height)
            if container.frame != wanted { container.frame = wanted }
            if titlebar.frame != container.bounds { titlebar.frame = container.bounds }
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                guard let button = window.standardWindowButton(kind) else { continue }
                let y = ((titlebar.bounds.height - button.frame.height) / 2).rounded()
                if button.frame.minY != y { button.setFrameOrigin(NSPoint(x: button.frame.minX, y: y)) }
            }

            // A re-layout that resets the bar's frame should be put right straight away.
            if observedContainer !== container {
                observedContainer = container
                container.postsFrameChangedNotifications = true
                observers.append(observe(NSView.frameDidChangeNotification, object: container))
            }
        }
    }
}
