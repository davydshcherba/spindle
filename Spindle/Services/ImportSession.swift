import Foundation
import Observation

/// Observable progress of a running (or just-finished) import. The UI renders
/// this directly; `LibraryService` is the only writer.
@Observable
final class ImportSession {
    enum Phase { case scanning, importing, finished }

    enum Status: Equatable {
        case waiting
        case reading
        case added
        case skipped
        case failed(String)
    }

    struct Entry: Identifiable, Equatable {
        let id: Int
        let name: String
        var status: Status
    }

    private(set) var phase: Phase = .scanning
    private(set) var sourceName = ""
    private(set) var entries: [Entry] = []
    private(set) var addedCount = 0
    private(set) var skippedCount = 0
    private(set) var failedCount = 0
    private(set) var isCancelled = false

    @ObservationIgnored private let startedAt = Date()

    var total: Int { entries.count }
    var completedCount: Int { addedCount + skippedCount + failedCount }
    var isFinished: Bool { phase == .finished }
    var fractionCompleted: Double { total == 0 ? 0 : Double(completedCount) / Double(total) }

    var estimatedSecondsRemaining: TimeInterval? {
        guard completedCount >= 3, total > completedCount, !isFinished else { return nil }
        let elapsed = Date().timeIntervalSince(startedAt)
        return elapsed / Double(completedCount) * Double(total - completedCount)
    }

    /// A short window of rows around the current progress, like the design's list.
    var visibleEntries: [Entry] {
        guard !entries.isEmpty else { return [] }
        let size = 4
        let start = max(0, min(completedCount - 2, entries.count - size))
        return Array(entries[start..<min(entries.count, start + size)])
    }

    // MARK: Mutation (LibraryService only)

    func startScanning(source: String) {
        phase = .scanning
        sourceName = source
    }

    /// Registers the files found by a scan and returns the index of the first one.
    func begin(files: [URL]) -> Int {
        let base = entries.count
        entries.append(contentsOf: files.enumerated().map { offset, url in
            Entry(id: base + offset, name: url.lastPathComponent, status: .waiting)
        })
        phase = .importing
        return base
    }

    func setStatus(_ status: Status, at index: Int) {
        guard entries.indices.contains(index) else { return }
        let previous = entries[index].status
        guard previous != status else { return }
        entries[index].status = status

        switch previous {
        case .added: addedCount -= 1
        case .skipped: skippedCount -= 1
        case .failed: failedCount -= 1
        case .waiting, .reading: break
        }
        switch status {
        case .added: addedCount += 1
        case .skipped: skippedCount += 1
        case .failed: failedCount += 1
        case .waiting, .reading: break
        }
    }

    func cancel() { isCancelled = true }
    func finish() { phase = .finished }
}
