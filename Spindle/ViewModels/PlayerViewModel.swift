import Foundation
import Observation

/// UI-facing facade over `PlayerService`: formatted times, scrubbing, volume,
/// the cover tint, and "play these tracks" helpers that take library `Track`s.
@Observable
final class PlayerViewModel {
    let service: PlayerService
    private let library: LibraryService
    private let artwork: ArtworkStore

    /// While the user drags the progress bar, this overrides the real position.
    private(set) var scrubFraction: Double?
    /// Dominant colour of the current cover, for the Now Playing background.
    private(set) var tint: RGBColor?

    @ObservationIgnored private var tintKey: String?
    @ObservationIgnored private var volumeBeforeMute: Float = 0.7

    init(service: PlayerService, library: LibraryService, artwork: ArtworkStore) {
        self.service = service
        self.library = library
        self.artwork = artwork
    }

    // MARK: Current item

    var currentItem: PlayerItem? { service.currentItem }
    var hasItem: Bool { currentItem != nil }
    var currentTrack: Track? { currentItem.flatMap { library.track(withID: $0.id) } }
    var isPlaying: Bool { service.isPlaying }
    var isShuffled: Bool { service.isShuffled }
    var repeatMode: RepeatMode { service.repeatMode }
    var upNext: [QueueEntry] { service.upNext }
    var currentEntry: QueueEntry? { service.currentEntry }
    var errorMessage: String? { service.errorMessage }

    /// "PLAYING FROM MY MUSIC"
    var contextLabel: String {
        service.contextName.isEmpty ? "" : "Playing from \(service.contextName)"
    }

    /// "Maren Volk — Low Tide Hours"
    var subtitle: String {
        guard let item = currentItem else { return "" }
        return "\(item.artist) \u{2014} \(item.album)"
    }

    func isCurrent(_ track: Track) -> Bool { currentItem?.id == track.id }

    // MARK: Progress

    var duration: TimeInterval { service.duration }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return scrubFraction ?? min(1, service.currentTime / duration)
    }

    private var displayedTime: TimeInterval {
        scrubFraction.map { $0 * duration } ?? service.currentTime
    }

    var elapsedText: String { TimeFormat.clock(hasItem ? displayedTime : 0) }
    var durationText: String { TimeFormat.clock(hasItem ? duration : 0) }
    var remainingText: String { TimeFormat.remaining(hasItem ? max(0, duration - displayedTime) : 0) }

    func beginScrub() { scrubFraction = progress }
    func updateScrub(_ fraction: Double) { scrubFraction = min(1, max(0, fraction)) }

    func endScrub(at fraction: Double) {
        let clamped = min(1, max(0, fraction))
        scrubFraction = nil
        service.seek(to: clamped * duration)
    }

    // MARK: Transport

    func togglePlayPause() { service.togglePlayPause() }
    func next() { service.next() }
    func previous() { service.previous() }
    func toggleShuffle() { service.toggleShuffle() }
    func cycleRepeat() { service.cycleRepeat() }
    func jump(to entry: QueueEntry) { service.jump(to: entry.id) }
    func removeFromQueue(_ entry: QueueEntry) { service.removeFromQueue(entry.id) }
    func dismissError() { service.clearError() }

    // MARK: Volume

    var volume: Double {
        get { Double(service.volume) }
        set { service.volume = Float(min(1, max(0, newValue))) }
    }

    var isMuted: Bool { service.volume == 0 }

    func toggleMute() {
        if isMuted {
            service.volume = volumeBeforeMute > 0 ? volumeBeforeMute : 0.7
        } else {
            volumeBeforeMute = service.volume
            service.volume = 0
        }
    }

    // MARK: Playing library tracks

    func play(_ track: Track, in tracks: [Track], context: String) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        service.play(tracks.map(\.playerItem), startIndex: index, context: context)
    }

    func play(_ tracks: [Track], context: String, shuffled: Bool = false) {
        guard !tracks.isEmpty else { return }
        let start = shuffled ? Int.random(in: tracks.indices) : 0
        service.play(tracks.map(\.playerItem), startIndex: start, context: context, shuffled: shuffled)
    }

    func playNext(_ tracks: [Track]) { service.playNext(tracks.map(\.playerItem)) }
    func addToQueue(_ tracks: [Track]) { service.addToQueue(tracks.map(\.playerItem)) }

    func toggleFavoriteOfCurrent() {
        guard let track = currentTrack else { return }
        library.toggleFavorite(track)
    }

    // MARK: Cover tint

    func refreshTint() async {
        guard let key = currentItem?.artworkKey else {
            tint = nil
            tintKey = nil
            return
        }
        guard key != tintKey else { return }
        let color = await artwork.dominantColor(forKey: key)
        guard currentItem?.artworkKey == key else { return }
        tint = color
        tintKey = key
    }
}
