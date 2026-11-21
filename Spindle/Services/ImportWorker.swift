import Foundation
import OSLog

/// A file that has been fully read and is ready to become a `Track`.
nonisolated struct PreparedFile: Sendable {
    let path: String
    let fileExtension: String
    let fileSize: Int64
    /// Name of the copy Spindle made in its library folder.
    let libraryFileName: String
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
/// extracting artwork and copying songs into the library folder. Produces plain `Sendable`
/// values; `LibraryService` turns them into `Track`s on the main actor.
nonisolated struct ImportWorker: Sendable {
    let artwork: ArtworkStore
    let files: LibraryFiles
    private let reader = MetadataReader()
    private static let log = Logger(subsystem: "com.spindle.Spindle", category: "Import")

    init(artwork: ArtworkStore, files: LibraryFiles) {
        self.artwork = artwork
        self.files = files
    }

    /// Expands files and folders (recursively) into a sorted list of supported audio files.
    @concurrent
    func collectAudioFiles(in urls: [URL]) async -> [URL] {
        Self.collect(urls)
    }

    @concurrent
    func prepare(_ url: URL) async -> Result<PreparedFile, ImportFailure> {
        let metadata = await reader.read(from: url)
        guard metadata.duration > 0 else {
            return .failure(ImportFailure(reason: "Not a playable audio file"))
        }

        // Only a file that really is audio is copied, so nothing else piles up in the library.
        let libraryFileName: String
        do {
            libraryFileName = try files.copyIn(url)
        } catch {
            Self.log.error("Copy failed: \(error.localizedDescription, privacy: .public)")
            return .failure(ImportFailure(reason: "Couldn't copy this file into your library"))
        }

        let artworkKey = metadata.artworkData.flatMap { artwork.store($0) }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let artist = metadata.artist ?? metadata.albumArtist ?? UnknownTag.artist

        return .success(PreparedFile(
            path: url.standardizedFileURL.path,
            fileExtension: url.pathExtension.lowercased(),
            fileSize: size,
            libraryFileName: libraryFileName,
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

    /// For a song imported before Spindle kept its own copies: follows the old bookmark to the
    /// original and copies it into the library. Nil if the original is gone.
    @concurrent
    func copyIntoLibrary(bookmark: Data) async -> String? {
        do {
            let original = try SecurityScopedBookmark.resolve(bookmark).url
            let isScoped = original.startAccessingSecurityScopedResource()
            defer { if isScoped { original.stopAccessingSecurityScopedResource() } }
            return try files.copyIn(original)
        } catch {
            Self.log.error("Couldn't copy an older song in: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
