import Foundation
import MediaPlayer

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Publishes what's playing to the system (Control Center, lock screen, media
/// keys) and routes remote commands back to the player.
final class NowPlayingService {
    private let player: PlayerService
    private let artwork: ArtworkStore
    private let center = MPNowPlayingInfoCenter.default()
    private var cachedArtwork: (key: String, artwork: MPMediaItemArtwork)?

    init(player: PlayerService, artwork: ArtworkStore) {
        self.player = player
        self.artwork = artwork
        Self.registerRemoteCommands(for: player)
        player.addEventHandler { [weak self] _ in self?.publish() }
    }

    // MARK: Now Playing info

    /// Writes the full info dictionary. Called on track, play/pause and seek changes only:
    /// the system extrapolates elapsed time from the playback rate in between.
    private func publish() {
        guard let item = player.currentItem else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPMediaItemPropertyAlbumTitle: item.album,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork = mediaArtwork(for: item) {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        center.nowPlayingInfo = info
        center.playbackState = player.isPlaying ? .playing : .paused
    }

    private func mediaArtwork(for item: PlayerItem) -> MPMediaItemArtwork? {
        guard let key = item.artworkKey else { return nil }
        if let cachedArtwork, cachedArtwork.key == key { return cachedArtwork.artwork }
        guard let image = artwork.image(forKey: key, maxPixelSize: 512) else { return nil }
        let made = Self.makeArtwork(image)
        cachedArtwork = (key, made)
        return made
    }

    /// `nonisolated` so the request handler isn't inferred as main-actor: MediaPlayer
    /// calls it from an arbitrary queue.
    private nonisolated static func makeArtwork(_ image: CGImage) -> MPMediaItemArtwork {
        let size = CGSize(width: image.width, height: image.height)
        #if canImport(AppKit)
        return MPMediaItemArtwork(boundsSize: size) { _ in NSImage(cgImage: image, size: size) }
        #else
        return MPMediaItemArtwork(boundsSize: size) { _ in UIImage(cgImage: image) }
        #endif
    }

    // MARK: Remote commands

    /// Registered from a `nonisolated` context because MediaPlayer invokes handlers
    /// off the main thread; each one hops to the main actor before touching the player.
    private nonisolated static func registerRemoteCommands(for player: PlayerService) {
        let commands = MPRemoteCommandCenter.shared()

        commands.playCommand.addTarget { _ in
            Task { @MainActor in player.play() }
            return .success
        }
        commands.pauseCommand.addTarget { _ in
            Task { @MainActor in player.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in player.togglePlayPause() }
            return .success
        }
        commands.nextTrackCommand.addTarget { _ in
            Task { @MainActor in player.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { _ in
            Task { @MainActor in player.previous() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in player.seek(to: position) }
            return .success
        }

        for command in [commands.playCommand, commands.pauseCommand, commands.togglePlayPauseCommand,
                        commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.changePlaybackPositionCommand] {
            command.isEnabled = true
        }
        // Spindle plays whole tracks; there is no sensible meaning for these.
        for command in [commands.skipForwardCommand, commands.skipBackwardCommand,
                        commands.seekForwardCommand, commands.seekBackwardCommand] {
            command.isEnabled = false
        }
    }
}
