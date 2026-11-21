#if os(iOS)
import AVFoundation

/// What an iPhone needs and a Mac doesn't: tell the system Spindle is a music player, so sound
/// keeps going with the screen off, and step aside politely for calls and unplugged headphones.
final class AudioSessionHandler {
    private let player: PlayerService
    private var observers: [any NSObjectProtocol] = []
    /// Playback was running when an interruption (a call, an alarm) began.
    private var wasPlayingBeforeInterruption = false

    init(player: PlayerService) {
        self.player = player
        // `.playback` keeps playing when the screen locks or the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

        player.addEventHandler { [weak self] event in
            if event == .playbackStateChanged { self?.activateIfPlaying() }
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated { self?.interruption(type: type, options: options) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.routeChanged(reason: reason) }
        })
    }

    private func activateIfPlaying() {
        guard player.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func interruption(type rawType: UInt?, options rawOptions: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = player.isPlaying
            player.pause()
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) { player.play() }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    /// Unplugging headphones stops the music instead of blasting it from the speaker.
    private func routeChanged(reason rawReason: UInt?) {
        guard let rawReason, let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        if reason == .oldDeviceUnavailable { player.pause() }
    }
}
#endif
