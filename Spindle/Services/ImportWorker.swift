import Foundation
import OSLog

/// A file that has been fully read and is ready to become a `Track`.
nonisolated struct PreparedFile: Sendable {
    let path: String
    let fileExtension: String
    let fileSize: Int64
    let bookmark: Data
    let title: String
    let artist: String
    let albumArtist: String
    let album: String
    let year: Int?
    let trackNumber: Int?
    let discNumber: Int?
    let duration: TimeInterval
    let artworkKey: String?
}

nonisolated struct ImportFailure: Error, Sendable {
    let reason: String
}

/// The off-main-actor half of importing: walking folders, reading tags,
/// extracting artwork and creating bookmarks. Produces plain `Sendable` values;
/// `LibraryService` turns them into `Track`s on the main actor.
nonisolated struct ImportWorker: Sendable {
    let artwork: ArtworkStore
    private let reader = MetadataReader()
    private static let log = Logger(subsystem: "com.spindle.Spindle", category: "Import")

    init(artwork: ArtworkStore) {
        self.artwork = artwork
    }

    /// Expands files and folders (recursively) into a sorted list of supported audio files.
    @concurrent
    func collectAudioFiles(in urls: [URL]) async -> [URL] {
        Self.collect(urls)
    }

    @concurrent
    func prepare(_ url: URL) async -> Result<PreparedFile, ImportFailure> {
        let bookmark: Data
        do {
            bookmark = try SecurityScopedBookmark.make(for: url)
        } catch {
            Self.log.error("Bookmark failed: \(error.localizedDescription, privacy: .public)")
            return .failure(ImportFailure(reason: "Couldn't keep access to this file"))
        }

        let metadata = await reader.read(from: url)
        guard metadata.duration > 0 else {
            return .failure(ImportFailure(reason: "Not a playable audio file"))
        }

        let artworkKey = metadata.artworkData.flatMap { artwork.store($0) }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let artist = metadata.artist ?? metadata.albumArtist ?? UnknownTag.artist

        return .success(PreparedFile(
            path: url.standardizedFileURL.path,
            fileExtension: url.pathExtension.lowercased(),
            fileSize: size,
            bookmark: bookmark,
            title: metadata.title ?? TagParsing.title(fromFilename: url),
            artist: artist,
            albumArtist: metadata.albumArtist ?? artist,
            album: metadata.album ?? UnknownTag.album,
            year: metadata.year,
            trackNumber: metadata.trackNumber,
            discNumber: metadata.discNumber,
            duration: metadata.duration,
            artworkKey: artworkKey
        ))
    }

    // Synchronous on purpose: NSDirectoryEnumerator can't be iterated from async code.
    private static func collect(_ urls: [URL]) -> [URL] {
        let fileManager = FileManager.default
        var seen = Set<String>()
        var files: [URL] = []

        func add(_ url: URL) {
            guard AudioFormat.isSupported(url), seen.insert(url.standardizedFileURL.path).inserted else { return }
            files.append(url)
        }

        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                while let next = enumerator?.nextObject() as? URL { add(next) }
            } else {
                add(url)
            }
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}
