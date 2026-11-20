import Foundation
import SwiftData

/// A user-made, ordered list of tracks.
///
/// Order is stored as an explicit array of track ids rather than a to-many
/// relationship, because SwiftData does not guarantee the order of relationship
/// collections. It also lets a track appear in a playlist only once without any
/// join-model bookkeeping.
@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastPlayedAt: Date?
    var trackIDs: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        trackIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastPlayedAt = nil
        self.trackIDs = trackIDs
    }
}
