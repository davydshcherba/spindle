import Foundation

/// Spindle's own copy of your music.
///
/// Importing copies each song into one folder inside the app, so the library keeps working
/// when the original is moved, renamed or deleted, or when a drive is unplugged. A song is
/// stored under a name of its own (`<uuid>.<ext>`) and a `Track` remembers only that name, never
/// a full path: the app's container can move (an iPhone gives it a new location after an
/// update), but the folder always sits in the same place relative to it.
nonisolated struct LibraryFiles: Sendable {
    let directory: URL

    init(directory: URL = Self.defaultDirectory()) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func defaultDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Spindle/Music", directoryHint: .isDirectory)
    }

    func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    /// Copies `source` into the library and returns the name it was stored under. Clones the
    /// file instead of duplicating its bytes where the volume allows it (APFS).
    func copyIn(_ source: URL) throws -> String {
        let fileName = Self.storedName(for: source)
        try FileManager.default.copyItem(at: source, to: url(for: fileName))
        return fileName
    }

    /// Deletes the library's copy. The original the user imported is never touched.
    func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    private static func storedName(for source: URL) -> String {
        let fileExtension = source.pathExtension.lowercased()
        let id = UUID().uuidString
        return fileExtension.isEmpty ? id : "\(id).\(fileExtension)"
    }
}
