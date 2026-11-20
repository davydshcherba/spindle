import Foundation
import Observation
import OSLog
import SwiftData

/// Owns the library: importing files, the track list, and playlists.
///
/// All persistence goes through here so view models stay free of SwiftData
/// details. Heavy work (directory walks, tag reading, artwork encoding) runs in
/// `ImportWorker` off the main actor; this class only touches the model context
/// on the main actor.
@Observable
final class LibraryService {
    // MARK: Observable state

    private(set) var tracks: [Track] = []
    private(set) var playlists: [Playlist] = []
    /// Bumped on every change that view models should recompute derived data for.
    private(set) var revision = 0
    private(set) var importSession: ImportSession?
    private(set) var lastError: String?

    // MARK: Dependencies

    @ObservationIgnored let modelContext: ModelContext
    @ObservationIgnored let artwork: ArtworkStore
    @ObservationIgnored private let worker: ImportWorker
    @ObservationIgnored private let log = Logger(subsystem: "com.spindle.Spindle", category: "Library")

    // MARK: Internals

    @ObservationIgnored private var tracksByID: [UUID: Track] = [:]
    @ObservationIgnored private var pendingBatches: [ImportBatch] = []
    @ObservationIgnored private var importTask: Task<Void, Never>?

    private struct ImportBatch {
        let urls: [URL]
        let skipDuplicates: Bool
        /// When set, every song goes into this one album instead of the one its tags name.
        let singleAlbum: String?
        let accesses: [SecurityScopedAccess]

        func stopAccessing() { accesses.forEach { $0.stop() } }
    }

    init(modelContext: ModelContext, artwork: ArtworkStore) {
        self.modelContext = modelContext
        self.artwork = artwork
        self.worker = ImportWorker(artwork: artwork)
        reload()
    }

    // MARK: Loading

    /// Re-reads everything from the store.
    func reload() {
        do {
            tracks = try modelContext.fetch(FetchDescriptor<Track>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]))
            playlists = try modelContext.fetch(FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.createdAt)]))
        } catch {
            fail("Couldn't load your library", error)
        }
        tracksByID = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        revision += 1
    }

    func track(withID id: UUID) -> Track? { tracksByID[id] }

    /// The tracks of a playlist in playlist order. Ids with no track (removed from
    /// the library) are skipped.
    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { tracksByID[$0] }
    }

    func dismissError() { lastError = nil }

    // MARK: Importing

    /// Imports files and/or folders. Returns immediately; progress is published on
    /// `importSession`. Calling this while an import is running queues the new items.
    ///
    /// Security scope is opened right away, because URLs from drag-and-drop or an open
    /// panel are only reliably accessible for a limited time.
    func importItems(_ urls: [URL], skipDuplicates: Bool = true, singleAlbum: String? = nil) {
        guard !urls.isEmpty else { return }
        pendingBatches.append(ImportBatch(
            urls: urls,
            skipDuplicates: skipDuplicates,
            singleAlbum: singleAlbum,
            accesses: urls.map(SecurityScopedAccess.init(url:))
        ))
        if importSession == nil || importSession?.isFinished == true {
            importSession = ImportSession()
        }
        guard importTask == nil else { return }
        importTask = Task { await runImportLoop() }
    }

    func cancelImport() { importSession?.cancel() }

    func dismissImportSession() {
        if importSession?.isFinished == true { importSession = nil }
    }

    /// Suspends until the running import (if any) has finished.
    func waitForImport() async { await importTask?.value }

    private func runImportLoop() async {
        guard let session = importSession else {
            importTask = nil
            return
        }
        while !pendingBatches.isEmpty, !session.isCancelled {
            let batch = pendingBatches.removeFirst()
            await process(batch, session: session)
            batch.stopAccessing()
        }
        pendingBatches.forEach { $0.stopAccessing() }
        pendingBatches.removeAll()
        session.finish()
        importTask = nil
    }

    private func process(_ batch: ImportBatch, session: ImportSession) async {
        session.startScanning(source: Self.describe(batch.urls))
        let files = await worker.collectAudioFiles(in: batch.urls)
        let base = session.begin(files: files)

        var knownPaths = Set(tracks.map(\.filePath))
        var knownKeys = Set(tracks.map(\.contentKey))
        var inserted: [Track] = []
        let flushThreshold = 25
        let concurrency = 4

        func flush() {
            guard !inserted.isEmpty else { return }
            save()
            for track in inserted { tracksByID[track.id] = track }
            tracks.append(contentsOf: inserted)
            inserted.removeAll()
            revision += 1
        }

        func integrate(_ offset: Int, _ result: Result<PreparedFile, ImportFailure>) {
            switch result {
            case .failure(let failure):
                session.setStatus(.failed(failure.reason), at: base + offset)
            case .success(let file):
                let track = Track(
                    title: file.title, artist: file.artist,
                    albumArtist: batch.singleAlbum == nil ? file.albumArtist : LibraryDefaults.variousArtists,
                    album: batch.singleAlbum ?? file.album,
                    year: file.year, trackNumber: file.trackNumber, discNumber: file.discNumber,
                    duration: file.duration, fileSize: file.fileSize, fileExtension: file.fileExtension,
                    filePath: file.path, bookmarkData: file.bookmark, artworkKey: file.artworkKey
                )
                if batch.skipDuplicates, knownPaths.contains(track.filePath) || knownKeys.contains(track.contentKey) {
                    session.setStatus(.skipped, at: base + offset)
                    return
                }
                modelContext.insert(track)
                knownPaths.insert(track.filePath)
                knownKeys.insert(track.contentKey)
                inserted.append(track)
                session.setStatus(.added, at: base + offset)
                if inserted.count >= flushThreshold { flush() }
            }
        }

        let worker = self.worker
        await withTaskGroup(of: (Int, Result<PreparedFile, ImportFailure>).self) { group in
            var running = 0
            for (offset, url) in files.enumerated() {
                if session.isCancelled { break }
                if batch.skipDuplicates, knownPaths.contains(url.standardizedFileURL.path) {
                    session.setStatus(.skipped, at: base + offset)
                    continue
                }
                if running >= concurrency, let finished = await group.next() {
                    running -= 1
                    integrate(finished.0, finished.1)
                }
                if session.isCancelled { break }
                session.setStatus(.reading, at: base + offset)
                group.addTask { (offset, await worker.prepare(url)) }
                running += 1
            }
            while let finished = await group.next() {
                integrate(finished.0, finished.1)
            }
        }
        flush()
    }

    private static func describe(_ urls: [URL]) -> String {
        guard urls.count == 1, let url = urls.first else { return "\(urls.count) items" }
        return url.lastPathComponent
    }

    // MARK: Editing tracks

    /// Changes what Spindle shows for a track. The audio file itself is never modified.
    func update(_ track: Track, with edit: TrackEdit) {
        track.title = edit.title
        track.artist = edit.artist
        track.albumArtist = edit.albumArtist
        track.album = edit.album
        track.year = edit.year
        track.trackNumber = edit.trackNumber
        if case .set(let key) = edit.cover { track.artworkKey = key }
        save()
        revision += 1
    }

    /// Applies an album edit to every song in the album. Albums with the same name and album
    /// artist are one album, so renaming an album to match another merges them.
    func update(_ tracks: [Track], with edit: AlbumEdit) {
        for track in tracks {
            track.album = edit.title
            track.albumArtist = edit.artist
            if case .set(let year) = edit.year { track.year = year }
            if case .set(let key) = edit.cover { track.artworkKey = key }
        }
        save()
        revision += 1
    }

    /// Puts every song in one album, whatever its tags say. Artist names are kept.
    func putAllInOneAlbum(named name: String = LibraryDefaults.songsAlbum) {
        for track in tracks {
            track.album = name
            track.albumArtist = LibraryDefaults.variousArtists
        }
        save()
        revision += 1
    }

    /// Called when a bookmark resolved as stale; the refreshed one keeps working.
    func updateBookmark(forTrackWithID id: UUID, to data: Data) {
        guard let track = tracksByID[id] else { return }
        track.bookmarkData = data
        save()
    }

    func remove(_ tracksToRemove: [Track]) {
        guard !tracksToRemove.isEmpty else { return }
        let ids = Set(tracksToRemove.map(\.id))
        for track in tracksToRemove { modelContext.delete(track) }
        for playlist in playlists where playlist.trackIDs.contains(where: ids.contains) {
            playlist.trackIDs.removeAll(where: ids.contains)
            playlist.updatedAt = .now
        }
        tracks.removeAll { ids.contains($0.id) }
        for id in ids { tracksByID[id] = nil }
        save()
        revision += 1
    }

    // MARK: Playlists

    @discardableResult
    func createPlaylist(named name: String, adding trackIDs: [UUID] = []) -> Playlist {
        let playlist = Playlist(name: resolvedName(name), trackIDs: trackIDs.removingDuplicates())
        modelContext.insert(playlist)
        playlists.append(playlist)
        save()
        revision += 1
        return playlist
    }

    func rename(_ playlist: Playlist, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != playlist.name else { return }
        playlist.name = trimmed
        playlist.updatedAt = .now
        save()
        revision += 1
    }

    /// Saves a new name and/or cover picture together. A blank name keeps the old one.
    func update(_ playlist: Playlist, name: String, cover: Change<String?>) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { playlist.name = trimmed }
        if case .set(let key) = cover { playlist.coverKey = key }
        playlist.updatedAt = .now
        save()
        revision += 1
    }

    func delete(_ playlist: Playlist) {
        modelContext.delete(playlist)
        playlists.removeAll { $0.id == playlist.id }
        save()
        revision += 1
    }

    /// Appends tracks that aren't already in the playlist. Returns how many were added.
    @discardableResult
    func add(trackIDs: [UUID], to playlist: Playlist) -> Int {
        let existing = Set(playlist.trackIDs)
        let fresh = trackIDs.removingDuplicates().filter { !existing.contains($0) }
        guard !fresh.isEmpty else { return 0 }
        playlist.trackIDs.append(contentsOf: fresh)
        playlist.updatedAt = .now
        save()
        revision += 1
        return fresh.count
    }

    func remove(trackIDs: Set<UUID>, from playlist: Playlist) {
        guard playlist.trackIDs.contains(where: trackIDs.contains) else { return }
        playlist.trackIDs.removeAll(where: trackIDs.contains)
        playlist.updatedAt = .now
        save()
        revision += 1
    }

    func markPlayed(_ playlist: Playlist) {
        playlist.lastPlayedAt = .now
        save()
        revision += 1
    }

    /// "New Playlist", then "New Playlist 2", … when the name is empty or taken.
    private func resolvedName(_ proposed: String) -> String {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "New Playlist" : trimmed
        let taken = Set(playlists.map { $0.name.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }

    // MARK: Persistence

    private func save() {
        do {
            try modelContext.save()
        } catch {
            fail("Couldn't save changes", error)
        }
    }

    private func fail(_ message: String, _ error: Error) {
        log.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        lastError = "\(message). \(error.localizedDescription)"
    }
}

extension Array where Element: Hashable {
    nonisolated func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
