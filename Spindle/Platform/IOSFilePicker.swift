#if os(iOS)
import UIKit
import UniformTypeIdentifiers

/// How the iPhone app asks for files: the system document picker (the Files app, iCloud Drive,
/// "On My iPhone"). The URLs it returns are security scoped, like the Mac's open panel's.
final class IOSFilePicker: FilePicking {
    /// Keeps the picker's delegate alive while the picker is on screen.
    private var activeDelegate: PickerDelegate?

    func pickFiles() async -> [URL] {
        await present(types: AudioFormat.contentTypes, allowsMultiple: true)
    }

    func pickFolders() async -> [URL] {
        await present(types: [.folder], allowsMultiple: true)
    }

    func pickImage() async -> URL? {
        await present(types: [.image], allowsMultiple: false).first
    }

    private func present(types: [UTType], allowsMultiple: Bool) async -> [URL] {
        guard let presenter = Self.topViewController() else { return [] }
        return await withCheckedContinuation { continuation in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
            picker.allowsMultipleSelection = allowsMultiple
            let delegate = PickerDelegate { [weak self] urls in
                self?.activeDelegate = nil
                continuation.resume(returning: urls)
            }
            activeDelegate = delegate
            picker.delegate = delegate
            presenter.present(picker, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

private final class PickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let finish: ([URL]) -> Void

    init(finish: @escaping ([URL]) -> Void) { self.finish = finish }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish([])
    }
}
#endif
