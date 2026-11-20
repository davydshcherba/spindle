import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FixtureError: Error {
    case exportUnavailable
    case flacUnavailable
    case coverEncodingFailed
}

struct FixtureTags {
    var title: String?
    var artist: String?
    var albumArtist: String?
    var album: String?
    var track: Int?
    var year: Int?
    var cover: Data?
}

/// Builds tiny real audio files (with tags and artwork) so tests exercise the same
/// code paths as user files, without shipping binary fixtures.
enum Fixtures {
    static func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "SpindleTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Cover art

    static func coverJPEG(red: Double, green: Double, blue: Double, side: Int = 64) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { throw FixtureError.coverEncodingFailed }
        context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        guard let image = context.makeImage() else { throw FixtureError.coverEncodingFailed }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FixtureError.coverEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.coverEncodingFailed }
        return output as Data
    }

    // MARK: WAV

    static func writeWAV(to url: URL, seconds: Double = 2, frequency: Double = 440, sampleRate: Int = 44_100) throws {
        let frames = Int(seconds * Double(sampleRate))
        var data = Data()

        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        data.append(contentsOf: "RIFF".utf8)
        append32(UInt32(36 + frames * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append32(16)
        append16(1) // PCM
        append16(1) // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))
        append16(2)
        append16(16)
        data.append(contentsOf: "data".utf8)
        append32(UInt32(frames * 2))
        for index in 0..<frames {
            let phase = 2 * Double.pi * frequency * Double(index) / Double(sampleRate)
            append16(UInt16(bitPattern: Int16(sin(phase) * 3000)))
        }
        try data.write(to: url)
    }

    // MARK: M4A

    static func writeM4A(to url: URL, tags: FixtureTags, seconds: Double = 2) async throws {
        let source = url.deletingLastPathComponent().appending(path: "source-\(UUID().uuidString).wav")
        try writeWAV(to: source, seconds: seconds)
        defer { try? FileManager.default.removeItem(at: source) }

        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetAppleM4A) else {
            throw FixtureError.exportUnavailable
        }
        var items: [AVMetadataItem] = []
        func text(_ id: AVMetadataIdentifier, _ value: String?) {
            guard let value else { return }
            let item = AVMutableMetadataItem()
            item.identifier = id
            item.value = value as NSString
            item.dataType = kCMMetadataBaseDataType_UTF8 as String
            items.append(item)
        }
        text(.iTunesMetadataSongName, tags.title)
        text(.iTunesMetadataArtist, tags.artist)
        text(.iTunesMetadataAlbumArtist, tags.albumArtist)
        text(.iTunesMetadataAlbum, tags.album)
        text(.iTunesMetadataReleaseDate, tags.year.map(String.init))
        if let track = tags.track {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataTrackNumber
            item.value = Data([0, 0, UInt8(track >> 8), UInt8(track & 0xFF), 0, 0, 0, 0]) as NSData
            item.dataType = kCMMetadataBaseDataType_RawData as String
            items.append(item)
        }
        if let cover = tags.cover {
            let item = AVMutableMetadataItem()
            item.identifier = .iTunesMetadataCoverArt
            item.value = cover as NSData
            item.dataType = kCMMetadataBaseDataType_JPEG as String
            items.append(item)
        }
        session.metadata = items
        try await session.export(to: url, as: .m4a)
    }

    // MARK: FLAC

    static func writeFLAC(to url: URL, tags: FixtureTags, seconds: Double = 2) throws {
        let sampleRate = 44_100.0
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
        ]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatInt16, interleaved: true)
            let frames = AVAudioFrameCount(seconds * sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
                  let samples = buffer.int16ChannelData?[0]
            else { throw FixtureError.flacUnavailable }
            buffer.frameLength = frames
            for index in 0..<Int(frames) {
                samples[index] = Int16(sin(2 * Double.pi * 440 * Double(index) / sampleRate) * 3000)
            }
            try file.write(from: buffer)
        }
        try injectFLACTags(into: url, tags: tags)
    }

    /// Rewrites the metadata blocks of a FLAC file: keeps STREAMINFO, adds a Vorbis
    /// comment block and (optionally) a front-cover picture block, keeps the audio frames.
    private static func injectFLACTags(into url: URL, tags: FixtureTags) throws {
        let original = try Data(contentsOf: url)
        guard original.prefix(4) == Data("fLaC".utf8) else { throw FixtureError.flacUnavailable }

        var offset = 4
        var streamInfo = Data()
        var isLast = false
        while !isLast {
            let first = original[offset]
            isLast = (first & 0x80) != 0
            let type = first & 0x7F
            let length = (Int(original[offset + 1]) << 16) | (Int(original[offset + 2]) << 8) | Int(original[offset + 3])
            if type == 0 { streamInfo = original.subdata(in: offset + 4..<offset + 4 + length) }
            offset += 4 + length
        }
        let audio = original.subdata(in: offset..<original.count)

        var blocks: [(type: UInt8, body: Data)] = [(0, streamInfo), (4, vorbisCommentBody(tags))]
        if let cover = tags.cover { blocks.append((6, pictureBody(cover))) }

        var output = Data("fLaC".utf8)
        for (index, block) in blocks.enumerated() {
            let last: UInt8 = index == blocks.count - 1 ? 0x80 : 0
            output.append(last | block.type)
            output.append(UInt8((block.body.count >> 16) & 0xFF))
            output.append(UInt8((block.body.count >> 8) & 0xFF))
            output.append(UInt8(block.body.count & 0xFF))
            output.append(block.body)
        }
        output.append(audio)
        try output.write(to: url)
    }

    private static func vorbisCommentBody(_ tags: FixtureTags) -> Data {
        var fields: [String] = []
        if let value = tags.title { fields.append("TITLE=\(value)") }
        if let value = tags.artist { fields.append("ARTIST=\(value)") }
        if let value = tags.albumArtist { fields.append("ALBUMARTIST=\(value)") }
        if let value = tags.album { fields.append("ALBUM=\(value)") }
        if let value = tags.track { fields.append("TRACKNUMBER=\(value)/12") }
        if let value = tags.year { fields.append("DATE=\(value)-05-01") }

        var data = Data()
        func appendLE(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
        let vendor = Data("spindle-tests".utf8)
        appendLE(vendor.count)
        data.append(vendor)
        appendLE(fields.count)
        for field in fields {
            let bytes = Data(field.utf8)
            appendLE(bytes.count)
            data.append(bytes)
        }
        return data
    }

    private static func pictureBody(_ cover: Data) -> Data {
        var data = Data()
        func appendBE(_ value: Int) { withUnsafeBytes(of: UInt32(value).bigEndian) { data.append(contentsOf: $0) } }
        let mime = Data("image/jpeg".utf8)
        appendBE(3) // front cover
        appendBE(mime.count)
        data.append(mime)
        appendBE(0) // empty description
        appendBE(64)
        appendBE(64)
        appendBE(24)
        appendBE(0)
        appendBE(cover.count)
        data.append(cover)
        return data
    }

    // MARK: MP3

    /// A real MPEG-1 Layer III stream of silent 128 kbps frames behind an ID3v2.3 tag.
    static func writeMP3(to url: URL, tags: FixtureTags, seconds: Double = 2) throws {
        var frames = [UInt8]()
        let frameCount = Int(seconds * 38.28)
        let frame = [UInt8](repeating: 0, count: 417)
        for _ in 0..<frameCount {
            frames.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])
            frames.append(contentsOf: frame.dropFirst(4))
        }

        var tagFrames = Data()
        func appendFrame(_ id: String, _ body: Data) {
            tagFrames.append(contentsOf: id.utf8)
            withUnsafeBytes(of: UInt32(body.count).bigEndian) { tagFrames.append(contentsOf: $0) }
            tagFrames.append(contentsOf: [0x00, 0x00])
            tagFrames.append(body)
        }
        func textFrame(_ id: String, _ value: String?) {
            guard let value else { return }
            appendFrame(id, Data([0x00]) + Data(value.utf8))
        }
        textFrame("TIT2", tags.title)
        textFrame("TPE1", tags.artist)
        textFrame("TPE2", tags.albumArtist)
        textFrame("TALB", tags.album)
        textFrame("TRCK", tags.track.map { "\($0)/12" })
        textFrame("TYER", tags.year.map(String.init))
        if let cover = tags.cover {
            var body = Data([0x00])
            body.append(Data("image/jpeg".utf8))
            body.append(contentsOf: [0x00, 0x03, 0x00])
            body.append(cover)
            appendFrame("APIC", body)
        }

        var file = Data("ID3".utf8)
        file.append(contentsOf: [0x03, 0x00, 0x00])
        let size = tagFrames.count
        file.append(contentsOf: [
            UInt8((size >> 21) & 0x7F), UInt8((size >> 14) & 0x7F), UInt8((size >> 7) & 0x7F), UInt8(size & 0x7F),
        ])
        file.append(tagFrames)
        file.append(contentsOf: frames)
        try file.write(to: url)
    }
}
