import Foundation
import UniformTypeIdentifiers

/// The single source of truth for which files Spindle will import.
nonisolated enum AudioFormat {
    static let fileExtensions: Set<String> = ["mp3", "m4a", "flac", "wav"]

    static func isSupported(_ url: URL) -> Bool {
        fileExtensions.contains(url.pathExtension.lowercased())
    }

    /// Content types for file pickers.
    static var contentTypes: [UTType] {
        fileExtensions.sorted().compactMap { UTType(filenameExtension: $0, conformingTo: .audio) }
    }
}
