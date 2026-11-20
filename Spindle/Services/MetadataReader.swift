import AVFoundation
import Foundation

/// Reads tags, duration and embedded artwork from an audio file.
///
/// Never throws: a file with unreadable tags is still a playable file, so the
/// caller gets whatever could be read and fills the gaps (e.g. from the filename).
nonisolated struct MetadataReader: Sendable {
    @concurrent
    func read(from url: URL) async -> TrackMetadata {
        let isFLAC = url.pathExtension.lowercased() == "flac"
        var metadata = (isFLAC ? FLACTagParser.parse(url: url) : nil) ?? TrackMetadata()

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        if metadata.duration <= 0, let time = try? await asset.load(.duration), time.isNumeric {
            metadata.duration = max(0, time.seconds)
        }
        // FLAC tags come from the dedicated parser above; everything else goes through AVFoundation.
        if !isFLAC {
            await mergeTags(from: asset, into: &metadata)
        }
        return metadata
    }

    private func mergeTags(from asset: AVURLAsset, into metadata: inout TrackMetadata) async {
        var items: [AVMetadataItem] = []
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                if let loaded = try? await asset.loadMetadata(for: format) {
                    items.append(contentsOf: loaded)
                }
            }
        }
        if let common = try? await asset.load(.commonMetadata) {
            items.append(contentsOf: common)
        }
        guard !items.isEmpty else { return }

        metadata.title = await Self.string(in: items, [.commonIdentifierTitle, .id3MetadataTitleDescription, .iTunesMetadataSongName])
        metadata.artist = await Self.string(in: items, [.commonIdentifierArtist, .id3MetadataLeadPerformer, .iTunesMetadataArtist])
        metadata.albumArtist = await Self.string(in: items, [.iTunesMetadataAlbumArtist, .id3MetadataBand])
        metadata.album = await Self.string(in: items, [.commonIdentifierAlbumName, .id3MetadataAlbumTitle, .iTunesMetadataAlbum])
        metadata.year = await Self.string(
            in: items,
            [.commonIdentifierCreationDate, .id3MetadataYear, .id3MetadataRecordingTime, .iTunesMetadataReleaseDate]
        ).flatMap(TagParsing.year)
        metadata.trackNumber = await Self.number(in: items, text: [.id3MetadataTrackNumber], packed: [.iTunesMetadataTrackNumber])
        metadata.discNumber = await Self.number(in: items, text: [.id3MetadataPartOfASet], packed: [.iTunesMetadataDiscNumber])
        metadata.artworkData = await Self.data(in: items, [.commonIdentifierArtwork, .id3MetadataAttachedPicture, .iTunesMetadataCoverArt])
    }

    // MARK: Item helpers

    private static func items(in items: [AVMetadataItem], for ids: [AVMetadataIdentifier]) -> [AVMetadataItem] {
        ids.flatMap { AVMetadataItem.metadataItems(from: items, filteredByIdentifier: $0) }
    }

    private static func string(in all: [AVMetadataItem], _ ids: [AVMetadataIdentifier]) async -> String? {
        for item in items(in: all, for: ids) {
            if let value = try? await item.load(.stringValue) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func data(in all: [AVMetadataItem], _ ids: [AVMetadataIdentifier]) async -> Data? {
        for item in items(in: all, for: ids) {
            if let value = try? await item.load(.dataValue), !value.isEmpty { return value }
        }
        return nil
    }

    /// `text` identifiers carry "3/12"-style strings (ID3); `packed` identifiers
    /// carry the iTunes binary form: two zero bytes, then big-endian number and total.
    private static func number(
        in all: [AVMetadataItem],
        text: [AVMetadataIdentifier],
        packed: [AVMetadataIdentifier]
    ) async -> Int? {
        for item in items(in: all, for: text) {
            if let value = try? await item.load(.stringValue), let number = TagParsing.leadingInt(value) {
                return number
            }
        }
        for item in items(in: all, for: packed) {
            if let value = try? await item.load(.dataValue), value.count >= 4 {
                let bytes = [UInt8](value)
                let number = (Int(bytes[2]) << 8) | Int(bytes[3])
                if number > 0 { return number }
            }
            if let value = try? await item.load(.numberValue), value.intValue > 0 {
                return value.intValue
            }
        }
        return nil
    }
}
