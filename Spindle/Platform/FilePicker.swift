import Foundation

#if os(macOS)
import AppKit
#endif

/// How the app asks the user for files. A seam so the import flow stays
/// platform-independent: macOS uses `NSOpenPanel`; iOS can supply a document picker later.
protocol FilePicking {
    func pickFiles() async -> [URL]
    func pickFolders() async -> [URL]
}

#if os(macOS)
struct MacFilePicker: FilePicking {
    func pickFiles() async -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Add music"
        panel.prompt = "Add"
        panel.message = "Choose MP3, M4A, FLAC or WAV files"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = AudioFormat.contentTypes
        return await run(panel)
    }

    func pickFolders() async -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Add a music folder"
        panel.prompt = "Add Folder"
        panel.message = "Folders are scanned with all their subfolders"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        return await run(panel)
    }

    private func run(_ panel: NSOpenPanel) async -> [URL] {
        let response = await panel.begin()
        return response == .OK ? panel.urls : []
    }
}
#endif
