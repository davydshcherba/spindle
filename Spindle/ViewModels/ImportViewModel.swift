import Foundation
import Observation

/// Drives the "Add music" dialog: choosing files or folders, drag and drop, and
/// presenting the import progress published by `LibraryService`.
@Observable
final class ImportViewModel {
    var skipDuplicates = true
    var isDropTargeted = false
    /// Put every new song in one album ("My songs") instead of the album its tags name.
    var putInOneAlbum: Bool {
        didSet { defaults.set(putInOneAlbum, forKey: Self.oneAlbumKey) }
    }

    private static let oneAlbumKey = "import.putInOneAlbum"
    @ObservationIgnored private let defaults: UserDefaults
    private let library: LibraryService
    private let picker: any FilePicking
    private let app: AppViewModel
    private let toasts: ToastCenter

    @ObservationIgnored private var observedFinish: ImportSession?

    init(
        library: LibraryService, picker: any FilePicking, app: AppViewModel, toasts: ToastCenter,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.putInOneAlbum = defaults.bool(forKey: Self.oneAlbumKey)
        self.library = library
        self.picker = picker
        self.app = app
        self.toasts = toasts
    }

    var session: ImportSession? { library.importSession }
    var isImporting: Bool { session.map { !$0.isFinished } ?? false }

    // MARK: Starting an import

    func chooseFiles() async {
        let urls = await picker.pickFiles()
        start(urls)
    }

    func chooseFolder() async {
        let urls = await picker.pickFolders()
        start(urls)
    }

    /// Returns whether the drop was accepted.
    func handleDrop(_ urls: [URL]) -> Bool {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return false }
        start(fileURLs)
        return true
    }

    private func start(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        library.importItems(
            urls, skipDuplicates: skipDuplicates,
            singleAlbum: putInOneAlbum ? LibraryDefaults.songsAlbum : nil
        )
        app.isAddMusicPresented = true
        Task { await announceCompletion() }
    }

    func cancel() { library.cancelImport() }

    /// Closes the dialog. A running import keeps going in the background.
    func close() {
        app.isAddMusicPresented = false
        library.dismissImportSession()
    }

    // MARK: Progress text

    /// "30 of 48 · about 20 s left"
    var progressText: String {
        guard let session else { return "" }
        var text = "\(session.completedCount) of \(session.total)"
        if let remaining = session.estimatedSecondsRemaining {
            text += " \u{00B7} about \(Self.shortDuration(remaining)) left"
        }
        return text
    }

    /// "48 added · 3 skipped · 1 failed"
    var resultText: String {
        guard let session else { return "" }
        var parts = ["\(session.addedCount) added"]
        if session.skippedCount > 0 { parts.append("\(session.skippedCount) skipped") }
        if session.failedCount > 0 { parts.append("\(session.failedCount) failed") }
        return parts.joined(separator: " \u{00B7} ")
    }

    private static func shortDuration(_ seconds: TimeInterval) -> String {
        seconds < 90 ? "\(max(5, Int((seconds / 5).rounded()) * 5)) s" : "\(Int((seconds / 60).rounded())) min"
    }

    // MARK: Completion toast

    /// If the dialog was closed while importing ("Continue in background"), tell the user when it's done.
    private func announceCompletion() async {
        await library.waitForImport()
        guard let session, session.isFinished else { return }
        if !app.isAddMusicPresented {
            let added = session.addedCount
            toasts.show(added > 0 ? "Added \(TimeFormat.count(added, "track"))" : "No new tracks were added")
            library.dismissImportSession()
        }
    }
}
