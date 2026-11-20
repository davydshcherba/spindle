import Foundation

/// Everything the player needs to know about a track, with no dependency on
/// SwiftData. This keeps `PlayerService` and `NowPlayingService` independent of
/// the persistence layer (and trivially testable).
nonisolated struct PlayerItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkKey: String?
    var bookmarkData: Data
}

/// One slot in the play queue. The queue can contain the same track twice, so
/// slots carry their own identity separate from the track id.
nonisolated struct QueueEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let item: PlayerItem

    init(_ item: PlayerItem) {
        self.id = UUID()
        self.item = item
    }
}

nonisolated enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}
