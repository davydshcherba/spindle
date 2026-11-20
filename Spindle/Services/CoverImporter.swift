import Foundation
import Observation

/// Lets the user pick a picture and turns it into a cover the app can use.
///
/// The picture is copied into the artwork store (resized, as JPEG), so the original file is
/// never needed again and nothing in the user's folders is touched.
@Observable
final class CoverImporter {
    enum Choice: Equatable {
        case cancelled
        case notAnImage
        case chosen(String)
    }

    @ObservationIgnored private let picker: any FilePicking
    @ObservationIgnored private let artwork: ArtworkStore

    init(picker: any FilePicking, artwork: ArtworkStore) {
        self.picker = picker
        self.artwork = artwork
    }

    func choose() async -> Choice {
        guard let url = await picker.pickImage() else { return .cancelled }
        guard let key = await artwork.storeImage(at: url) else { return .notAnImage }
        return .chosen(key)
    }
}
