import Foundation
import Observation

/// A single transient message ("Added to Late Night Drive") shown above the player bar.
@Observable
final class ToastCenter {
    private(set) var message: String?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(_ text: String, duration: Duration = .seconds(3)) {
        message = text
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { message = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}
