import AVFoundation
import MediaToolbox

/// Puts the equalizer inside AVPlayer's audio path.
///
/// AVPlayer has no equalizer of its own, but it lets an app listen in on the decoded audio and
/// change it before it reaches the speakers (an audio processing tap). Seeking, gapless
/// timing and the rest of the player keep working exactly as before.
nonisolated enum EqualizerTap {
    /// An audio mix that runs the equalizer over `asset`'s first audio track, to be set as the
    /// `audioMix` of the player item before it starts playing. `nil` if there is no audio track.
    static func audioMix(for asset: AVAsset, parameters: EqualizerParameters) async -> AVAudioMix? {
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return nil }

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(parameters).toOpaque(),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap
        )
        guard status == noErr, let tap else { return nil }

        let inputParameters = AVMutableAudioMixInputParameters(track: track)
        inputParameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [inputParameters]
        return mix
    }
}

/// What one tap keeps between its callbacks: its own filter memory, and the shared settings.
private nonisolated final class TapContext {
    let parameters: EqualizerParameters
    let processor: EqualizerProcessor

    init(parameters: EqualizerParameters) {
        self.parameters = parameters
        processor = EqualizerProcessor(parameters: parameters)
    }
}

private nonisolated func context(of tap: MTAudioProcessingTap) -> TapContext {
    Unmanaged<TapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
}

private nonisolated func tapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ storageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    guard let clientInfo else { return }
    let parameters = Unmanaged<EqualizerParameters>.fromOpaque(clientInfo).takeUnretainedValue()
    storageOut.pointee = Unmanaged.passRetained(TapContext(parameters: parameters)).toOpaque()
}

private nonisolated func tapFinalize(_ tap: MTAudioProcessingTap) {
    Unmanaged<TapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

private nonisolated func tapPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ format: UnsafePointer<AudioStreamBasicDescription>
) {
    let description = format.pointee
    let isFloat32 = description.mFormatID == kAudioFormatLinearPCM
        && description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        && description.mBitsPerChannel == 32
    context(of: tap).processor.prepare(
        sampleRate: description.mSampleRate,
        channelCount: Int(description.mChannelsPerFrame),
        isFloat32: isFloat32
    )
}

private nonisolated func tapUnprepare(_ tap: MTAudioProcessingTap) {}

private nonisolated func tapProcess(
    _ tap: MTAudioProcessingTap,
    _ frames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferList: UnsafeMutablePointer<AudioBufferList>,
    _ framesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    // Ask for the audio as it would have played, then change it in place.
    guard MTAudioProcessingTapGetSourceAudio(tap, frames, bufferList, flagsOut, nil, framesOut) == noErr else {
        framesOut.pointee = 0
        return
    }
    let context = context(of: tap)
    if context.processor.process(UnsafeMutableAudioBufferListPointer(bufferList), frames: framesOut.pointee) {
        context.parameters.recordProcessed(frames: framesOut.pointee)
    }
}
