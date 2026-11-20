import Foundation

/// Minimal FLAC metadata reader.
///
/// AVFoundation plays FLAC, but its Vorbis-comment and embedded-picture support is
/// undocumented, so tags are read straight from the metadata blocks at the start of
/// the file (https://xiph.org/flac/format.html) rather than depending on it. Only the
/// first few blocks are read; audio frames are never touched.
nonisolated enum FLACTagParser {
    private enum BlockType {
        static let streamInfo: UInt8 = 0
        static let vorbisComment: UInt8 = 4
        static let picture: UInt8 = 6
    }

    private static let frontCoverPictureType: UInt32 = 3

    static func parse(url: URL) -> TrackMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let magic = try? handle.read(upToCount: 4), magic.elementsEqual("fLaC".utf8) else { return nil }

        var metadata = TrackMetadata()
        var picture: (type: UInt32, data: Data)?
        var isLast = false

        while !isLast {
            guard let header = try? handle.read(upToCount: 4), header.count == 4 else { break }
            let h = [UInt8](header)
            isLast = (h[0] & 0x80) != 0
            let type = h[0] & 0x7F
            let length = (Int(h[1]) << 16) | (Int(h[2]) << 8) | Int(h[3])
            guard let body = try? handle.read(upToCount: length), body.count == length else { break }
            let bytes = [UInt8](body)

            switch type {
            case BlockType.streamInfo:
                if let seconds = duration(fromStreamInfo: bytes) { metadata.duration = seconds }
            case BlockType.vorbisComment:
                apply(vorbisComments: bytes, to: &metadata)
            case BlockType.picture:
                if let found = parsePicture(bytes) {
                    let isBetter = picture == nil || (found.type == frontCoverPictureType && picture?.type != frontCoverPictureType)
                    if isBetter { picture = found }
                }
            default:
                break
            }
        }

        metadata.artworkData = picture?.data
        return metadata
    }

    // MARK: Blocks

    private static func duration(fromStreamInfo b: [UInt8]) -> TimeInterval? {
        guard b.count >= 18 else { return nil }
        let rateHigh = Int(b[10]) << 12
        let rateMid = Int(b[11]) << 4
        let rateLow = Int(b[12]) >> 4
        let sampleRate = rateHigh | rateMid | rateLow

        var total = UInt64(b[13] & 0x0F) << 32
        total |= UInt64(b[14]) << 24
        total |= UInt64(b[15]) << 16
        total |= UInt64(b[16]) << 8
        total |= UInt64(b[17])

        guard sampleRate > 0, total > 0 else { return nil }
        return Double(total) / Double(sampleRate)
    }

    private static func apply(vorbisComments b: [UInt8], to metadata: inout TrackMetadata) {
        var reader = ByteReader(b)
        guard let vendorLength = reader.u32(.little), reader.skip(Int(vendorLength)),
              let count = reader.u32(.little) else { return }

        var fields: [String: String] = [:]
        for _ in 0..<count {
            guard let length = reader.u32(.little), let raw = reader.bytes(Int(length)) else { break }
            guard let text = String(bytes: raw, encoding: .utf8), let equals = text.firstIndex(of: "=") else { continue }
            let key = text[..<equals].uppercased()
            let value = text[text.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, fields[key] == nil { fields[key] = value }
        }

        metadata.title = fields["TITLE"]
        metadata.artist = fields["ARTIST"]
        metadata.album = fields["ALBUM"]
        metadata.albumArtist = fields["ALBUMARTIST"] ?? fields["ALBUM ARTIST"]
        metadata.trackNumber = fields["TRACKNUMBER"].flatMap(TagParsing.leadingInt)
        metadata.discNumber = fields["DISCNUMBER"].flatMap(TagParsing.leadingInt)
        metadata.year = (fields["DATE"] ?? fields["YEAR"]).flatMap(TagParsing.year)
    }

    private static func parsePicture(_ b: [UInt8]) -> (type: UInt32, data: Data)? {
        var reader = ByteReader(b)
        guard let type = reader.u32(.big),
              let mimeLength = reader.u32(.big), reader.skip(Int(mimeLength)),
              let descriptionLength = reader.u32(.big), reader.skip(Int(descriptionLength)),
              reader.skip(16), // width, height, depth, indexed colors
              let dataLength = reader.u32(.big),
              let data = reader.bytes(Int(dataLength))
        else { return nil }
        return (type, Data(data))
    }
}

/// Bounds-checked cursor over a byte array.
private nonisolated struct ByteReader {
    enum Endianness { case big, little }

    private let bytes: [UInt8]
    private var position = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func skip(_ count: Int) -> Bool {
        guard count >= 0, bytes.count - position >= count else { return false }
        position += count
        return true
    }

    mutating func bytes(_ count: Int) -> ArraySlice<UInt8>? {
        guard count >= 0, bytes.count - position >= count else { return nil }
        defer { position += count }
        return bytes[position..<position + count]
    }

    mutating func u32(_ endianness: Endianness) -> UInt32? {
        guard let slice = bytes(4) else { return nil }
        let b = Array(slice).map(UInt32.init)
        switch endianness {
        case .big: return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
        case .little: return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0]
        }
    }
}
