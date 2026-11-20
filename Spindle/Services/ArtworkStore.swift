import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Disk + memory cache for cover art.
///
/// Embedded artwork is extracted once at import, normalised to a JPEG of at most
/// `maxStoredPixelSize` and stored under a content hash, so every track on an
/// album shares one file. Views then decode small thumbnails on demand.
///
/// Platform-independent on purpose: it deals in `CGImage`, never `NSImage`/`UIImage`.
nonisolated final class ArtworkStore: @unchecked Sendable {
    // @unchecked Sendable: all stored properties are immutable `let`s and NSCache is thread-safe.

    static let maxStoredPixelSize = 1000
    private static let thumbnailBuckets = [128, 256, 512, 1024]

    private let directory: URL
    private let cache = NSCache<NSString, CGImage>()
    private let colorCache = NSCache<NSString, ColorBox>()

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        cache.totalCostLimit = 192 * 1024 * 1024
    }

    static func defaultDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Spindle/Artwork", directoryHint: .isDirectory)
    }

    // MARK: Writing

    /// Stores artwork and returns its key. CPU-heavy: call off the main actor.
    func store(_ data: Data) -> String? {
        let key = Self.hash(data)
        let file = fileURL(forKey: key)
        if FileManager.default.fileExists(atPath: file.path) { return key }
        guard let jpeg = Self.normalizedJPEG(from: data, maxPixelSize: Self.maxStoredPixelSize) else { return nil }
        do {
            try jpeg.write(to: file, options: .atomic)
            return key
        } catch {
            return nil
        }
    }

    // MARK: Reading

    /// Returns an already-decoded image without touching the disk.
    func cachedImage(forKey key: String, maxPixelSize: Int) -> CGImage? {
        cache.object(forKey: Self.cacheKey(key, maxPixelSize))
    }

    /// Decodes (or returns the cached) thumbnail. Synchronous disk + decode work.
    func image(forKey key: String, maxPixelSize: Int) -> CGImage? {
        if let cached = cachedImage(forKey: key, maxPixelSize: maxPixelSize) { return cached }
        let bucket = Self.bucket(for: maxPixelSize)
        guard let source = CGImageSourceCreateWithURL(fileURL(forKey: key) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: bucket,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        cache.setObject(image, forKey: Self.cacheKey(key, maxPixelSize), cost: image.width * image.height * 4)
        return image
    }

    /// Same as `image(forKey:maxPixelSize:)` but guaranteed to run off the caller's actor.
    @concurrent
    func loadImage(forKey key: String, maxPixelSize: Int) async -> CGImage? {
        image(forKey: key, maxPixelSize: maxPixelSize)
    }

    /// The most vivid colour of a cover, cached. Used to tint the Now Playing background.
    @concurrent
    func dominantColor(forKey key: String) async -> RGBColor? {
        if let cached = colorCache.object(forKey: key as NSString) { return cached.color }
        guard let image = image(forKey: key, maxPixelSize: 128),
              let color = DominantColor.compute(from: image) else { return nil }
        colorCache.setObject(ColorBox(color: color), forKey: key as NSString)
        return color
    }

    private final class ColorBox {
        let color: RGBColor
        init(color: RGBColor) { self.color = color }
    }

    // MARK: Helpers

    private func fileURL(forKey key: String) -> URL {
        directory.appending(path: "\(key).jpg", directoryHint: .notDirectory)
    }

    private static func bucket(for pixels: Int) -> Int {
        thumbnailBuckets.first { $0 >= pixels } ?? thumbnailBuckets[thumbnailBuckets.count - 1]
    }

    private static func cacheKey(_ key: String, _ pixels: Int) -> NSString {
        "\(key)@\(bucket(for: pixels))" as NSString
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedJPEG(from data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
