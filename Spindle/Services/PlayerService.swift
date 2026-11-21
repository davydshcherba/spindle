import AVFoundation
import Foundation
import Observation
import OSLog

nonisolated enum PlayerEvent: Sendable, Equatable {
    case itemChanged
    case playbackStateChanged
    case seeked
    case queueChanged
}

/// Plays a queue of tracks with AVPlayer, through the equalizer.
///
/// Knows nothing about SwiftData or SwiftUI: it is handed `PlayerItem`s and
/// finds their files in the library folder itself. State is `@Observable` for
/// views; other services (Now Playing) subscribe through `addEventHandler`.
@Observable
final class PlayerService {
    // MARK: Observable state

    private(set) var queue: [QueueEntry] = []
    private(set) var currentIndex: Int?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isShuffled: Bool
    /// Where the queue came from, e.g. "My Music" or a playlist name.
    private(set) var contextName = ""
    private(set) var errorMessage: String?

    var repeatMode: RepeatMode {
        didSet { defaults.set(repeatMode.rawValue, forKey: Keys.repeatMode) }
    }

    var volume: Float {
        didSet {
            player.volume = volume
            defaults.set(volume, forKey: Keys.volume)
        }
    }

    // MARK: Derived

    var currentEntry: QueueEntry? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    var currentItem: PlayerItem? { currentEntry?.item }

    var upNext: [QueueEntry] {
        guard let currentIndex, currentIndex + 1 < queue.count else { return [] }
        return Array(queue[(currentIndex + 1)...])
    }

    var hasNext: Bool {
        guard let currentIndex else { return false }
        return currentIndex + 1 < queue.count || repeatMode == .all
    }

    var hasPrevious: Bool { currentIndex != nil }

    // MARK: Internals

    private enum Keys {
        static let volume = "player.volume"
        static let shuffle = "player.shuffle"
        static let repeatMode = "player.repeat"
    }

    /// A restart (rather than going back) is offered once this much of a track has played.
    private static let restartThreshold: TimeInterval = 3

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let equalizer: EqualizerParameters
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let log = Logger(subsystem: "com.spindle.Spindle", category: "Player")
    @ObservationIgnored private var originalOrder: [QueueEntry] = []
    @ObservationIgnored private let files: LibraryFiles
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var pendingSeeks = 0
    @ObservationIgnored private var consecutiveFailures = 0
    @ObservationIgnored private var handlers: [(PlayerEvent) -> Void] = []

    /// `equalizer` holds the settings the music is run through; the default is a flat one that
    /// nobody changes. `files` is the library folder the songs are played from.
    init(
        defaults: UserDefaults = .standard,
        equalizer: EqualizerParameters = EqualizerParameters(),
        files: LibraryFiles = LibraryFiles()
    ) {
        self.defaults = defaults
        self.equalizer = equalizer
        self.files = files
        self.volume = defaults.object(forKey: Keys.volume) as? Float ?? 0.7
        self.isShuffled = defaults.bool(forKey: Keys.shuffle)
        self.repeatMode = defaults.string(forKey: Keys.repeatMode).flatMap(RepeatMode.init(rawValue:)) ?? .off
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = false

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.timeDidAdvance(to: time) }
        }
    }

    func addEventHandler(_ handler: @escaping (PlayerEvent) -> Void) {
        handlers.append(handler)
    }

    // MARK: Starting playback

    /// Replaces the queue and starts playing `items[startIndex]`.
    /// Pass `shuffled` to force shuffle on or off; nil keeps the current setting.
    func play(_ items: [PlayerItem], startIndex: Int = 0, context: String, shuffled: Bool? = nil) {
        guard items.indices.contains(startIndex) else { return }
        contextName = context
        if let shuffled { setShuffled(shuffled, rebuildQueue: false) }

        originalOrder = items.map(QueueEntry.init)
        let start = originalOrder[startIndex]
        if isShuffled {
            var rest = originalOrder
            rest.remove(at: startIndex)
            queue = [start] + rest.shuffled()
            currentIndex = 0
        } else {
            queue = originalOrder
            currentIndex = startIndex
        }
        consecutiveFailures = 0
        emit(.queueChanged)
        load(at: currentIndex ?? 0, autoplay: true)
    }

    // MARK: Transport

    func play() {
        guard currentItem != nil else { return }
        if hasFinishedLastItem { seek(to: 0) }
        player.play()
        setPlaying(true)
    }

    func pause() {
        player.pause()
        setPlaying(false)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func next() {
        guard let currentIndex else { return }
        if currentIndex + 1 < queue.count {
            load(at: currentIndex + 1, autoplay: true)
        } else if repeatMode == .all {
            load(at: 0, autoplay: true)
        } else {
            stopAtEnd()
        }
    }

    /// Restarts the track if it has been playing for a few seconds; otherwise goes back one.
    func previous() {
        guard let currentIndex else { return }
        if currentTime > Self.restartThreshold {
            seek(to: 0)
        } else if currentIndex > 0 {
            load(at: currentIndex - 1, autoplay: true)
        } else if repeatMode == .all, queue.count > 1 {
            load(at: queue.count - 1, autoplay: true)
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: TimeInterval) {
        guard currentItem != nil else { return }
        let target = min(max(0, seconds), max(duration, 0))
        currentTime = target
        pendingSeeks += 1
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) {
            [weak self] _ in
            Task { @MainActor in
                self?.pendingSeeks -= 1
                self?.emit(.seeked)
            }
        }
    }

    func toggleShuffle() { setShuffled(!isShuffled, rebuildQueue: true) }
    func cycleRepeat() { repeatMode = repeatMode.next }

    // MARK: Queue editing

    /// Plays this entry now (used by the queue list).
    func jump(to entryID: QueueEntry.ID) {
        guard let index = queue.firstIndex(where: { $0.id == entryID }) else { return }
        load(at: index, autoplay: true)
    }

    func playNext(_ items: [PlayerItem]) {
        insert(items, afterCurrent: true)
    }

    func addToQueue(_ items: [PlayerItem]) {
        insert(items, afterCurrent: false)
    }

    func removeFromQueue(_ entryID: QueueEntry.ID) {
        guard let index = queue.firstIndex(where: { $0.id == entryID }), index != currentIndex else { return }
        queue.remove(at: index)
        originalOrder.removeAll { $0.id == entryID }
        if let currentIndex, index < currentIndex { self.currentIndex = currentIndex - 1 }
        emit(.queueChanged)
    }

    /// Stops playback and empties the queue.
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        detachItemObservers()
        queue = []
        originalOrder = []
        currentIndex = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        emit(.queueChanged)
        emit(.itemChanged)
    }

    /// Drops tracks that were removed from the library, stopping if the current one is among them.
    func removeItems(withIDs ids: Set<UUID>) {
        guard queue.contains(where: { ids.contains($0.item.id) }) else { return }
        if let current = currentItem, ids.contains(current.id) {
            stop()
            return
        }
        let currentID = currentEntry?.id
        queue.removeAll { ids.contains($0.item.id) }
        originalOrder.removeAll { ids.contains($0.item.id) }
        currentIndex = queue.firstIndex { $0.id == currentID }
        emit(.queueChanged)
    }

    /// Replaces the stored snapshot of a track after its info was edited, so the player bar,
    /// queue and Now Playing show the new title/artist/album straight away.
    func updateItem(_ item: PlayerItem) { updateItems([item]) }

    func updateItems(_ items: [PlayerItem]) {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        func replace(in entries: inout [QueueEntry]) -> Bool {
            var changed = false
            for index in entries.indices {
                if let updated = byID[entries[index].item.id] {
                    entries[index] = QueueEntry(id: entries[index].id, item: updated)
                    changed = true
                }
            }
            return changed
        }
        let wasQueued = replace(in: &queue)
        _ = replace(in: &originalOrder)
        guard wasQueued else { return }
        let currentWasEdited = currentItem.map { byID[$0.id] != nil } ?? false
        emit(currentWasEdited ? .itemChanged : .queueChanged)
    }

    func clearError() { errorMessage = nil }

    // MARK: Loading

    private func load(at index: Int, autoplay: Bool) {
        guard queue.indices.contains(index) else { return }
        let entry = queue[index]
        currentIndex = index
        currentTime = 0
        duration = entry.item.duration

        detachItemObservers()

        guard let fileName = entry.item.libraryFileName, files.exists(fileName) else {
            log.error("No library file for \(entry.item.title, privacy: .private)")
            emit(.itemChanged)
            didFail(entry, reason: "The file is missing from your library.")
            return
        }
        let url = files.url(for: fileName)

        let item = AVPlayerItem(url: url)
        attachObservers(to: item, entry: entry)
        player.replaceCurrentItem(with: item)
        if autoplay { setPlaying(true) }
        attachEqualizer(to: item, startPlaying: autoplay)
        emit(.itemChanged)
    }

    /// Runs the track through the equalizer. Playback starts once that's in place, a moment
    /// later, so the first notes are never heard flat.
    private func attachEqualizer(to item: AVPlayerItem, startPlaying: Bool) {
        let parameters = equalizer
        Task { [weak self] in
            let mix = await EqualizerTap.audioMix(for: item.asset, parameters: parameters)
            // The track may have been skipped, or playback paused, while the mix was loading.
            guard let self, player.currentItem === item else { return }
            item.audioMix = mix
            if startPlaying, isPlaying { player.play() }
        }
    }

    private func attachObservers(to item: AVPlayerItem, entry: QueueEntry) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.itemDidFinish() }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let seconds = item.duration.isNumeric ? item.duration.seconds : 0
            Task { @MainActor in self?.itemStatusChanged(status, duration: seconds, entry: entry) }
        }
    }

    private func detachItemObservers() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
    }

    private func itemStatusChanged(_ status: AVPlayerItem.Status, duration seconds: TimeInterval, entry: QueueEntry) {
        guard entry.id == currentEntry?.id else { return }
        switch status {
        case .readyToPlay:
            consecutiveFailures = 0
            if seconds > 0, abs(seconds - duration) > 0.5 { duration = seconds }
        case .failed:
            didFail(entry, reason: "The file couldn't be decoded.")
        default:
            break
        }
    }

    // MARK: Advancing

    private func itemDidFinish() {
        if repeatMode == .one {
            seek(to: 0)
            player.play()
            setPlaying(true)
        } else {
            next()
        }
    }

    private func stopAtEnd() {
        player.pause()
        setPlaying(false)
        seek(to: 0)
    }

    private var hasFinishedLastItem: Bool {
        guard let currentIndex, currentIndex == queue.count - 1 else { return false }
        return duration > 0 && currentTime >= duration - 0.5
    }

    private func didFail(_ entry: QueueEntry, reason: String) {
        errorMessage = "Can't play “\(entry.item.title)”. \(reason)"
        consecutiveFailures += 1
        if let currentIndex, currentIndex + 1 < queue.count, consecutiveFailures < queue.count {
            load(at: currentIndex + 1, autoplay: true)
        } else {
            player.pause()
            setPlaying(false)
        }
    }

    // MARK: Shuffle & queue helpers

    private func setShuffled(_ value: Bool, rebuildQueue: Bool) {
        guard value != isShuffled else { return }
        isShuffled = value
        defaults.set(value, forKey: Keys.shuffle)
        guard rebuildQueue, let current = currentEntry else { return }
        if value {
            queue = [current] + queue.filter { $0.id != current.id }.shuffled()
            currentIndex = 0
        } else {
            queue = originalOrder
            currentIndex = queue.firstIndex { $0.id == current.id }
        }
        emit(.queueChanged)
    }

    private func insert(_ items: [PlayerItem], afterCurrent: Bool) {
        guard !items.isEmpty else { return }
        let entries = items.map(QueueEntry.init)
        guard let currentIndex, let current = currentEntry else {
            // Nothing playing: the items become the queue and wait for play().
            originalOrder = entries
            queue = entries
            self.currentIndex = 0
            load(at: 0, autoplay: false)
            emit(.queueChanged)
            return
        }
        if afterCurrent {
            queue.insert(contentsOf: entries, at: currentIndex + 1)
            let originalIndex = originalOrder.firstIndex { $0.id == current.id } ?? originalOrder.count - 1
            originalOrder.insert(contentsOf: entries, at: originalIndex + 1)
        } else {
            queue.append(contentsOf: entries)
            originalOrder.append(contentsOf: entries)
        }
        emit(.queueChanged)
    }

    // MARK: Time & state

    private func timeDidAdvance(to time: CMTime) {
        guard pendingSeeks == 0, time.isNumeric else { return }
        currentTime = min(max(0, time.seconds), max(duration, time.seconds))
    }

    private func setPlaying(_ value: Bool) {
        guard value != isPlaying else { return }
        isPlaying = value
        emit(.playbackStateChanged)
    }

    private func emit(_ event: PlayerEvent) {
        for handler in handlers { handler(event) }
    }
}
