import XCTest

/// Launches the iPhone app with a small library: four tagged songs with covers, three albums, and
/// the four sample playlists the debug launch makes. The app runs on a throwaway store, so nothing
/// a test does touches a real library.
class PhoneUITestCase: XCTestCase {
    @MainActor private(set) var app: XCUIApplication!

    @MainActor override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        let folder = try await Self.makeMusicFolder()
        app = XCUIApplication()
        app.launchEnvironment["SPINDLE_UI_TESTING"] = "1"
        app.launchEnvironment["SPINDLE_SEED_DIR"] = folder.path
        app.launch()

        // The songs are imported in the background; the first one showing means it is done.
        XCTAssertTrue(songRow("Glass Rooms").waitForExistence(timeout: 40), "the sample library never appeared")
    }

    // MARK: Finding things

    /// Any element whose label contains `text`: a list row, a card, a button.
    @MainActor func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    /// A song's row in a list. Its label reads "Title, Artist · Album, 2:30", or "1, Title, Artist,
    /// 2:30" on an album's own page, where rows are numbered.
    @MainActor func songRow(_ title: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@", "\(title),", ", \(title),")
        ).firstMatch
    }

    @MainActor func showSection(_ name: String) {
        app.segmentedControls.buttons[name].tap()
    }

    @MainActor func showTab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    /// Press and hold a row for its menu, then pick an item.
    @MainActor func chooseFromMenu(of row: XCUIElement, _ item: String) {
        row.press(forDuration: 1.2)
        let button = app.buttons[item]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the menu has no \u{201C}\(item)\u{201D}")
        button.tap()
    }

    // MARK: Sample library

    private static func makeMusicFolder() async throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpindleUITestMusic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let albums: [(artist: String, title: String, year: Int, color: (Double, Double, Double), songs: [String])] = [
            ("Maren Volk", "Low Tide Hours", 2024, (0.86, 0.69, 0.27), ["Glass Rooms", "Undertow"]),
            ("The Quiet Arcade", "Paper Lanterns", 2022, (0.72, 0.36, 0.25), ["Lantern Song"]),
            ("Teo Brannigan", "Field Notes", 2022, (0.47, 0.52, 0.30), ["Morning Static"]),
        ]
        for album in albums {
            let folder = root.appendingPathComponent(album.title, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let cover = try Fixtures.coverJPEG(red: album.color.0, green: album.color.1, blue: album.color.2, side: 300)
            for (index, song) in album.songs.enumerated() {
                let tags = FixtureTags(
                    title: song, artist: album.artist, albumArtist: album.artist, album: album.title,
                    track: index + 1, year: album.year, cover: cover
                )
                // Long enough that nothing finishes while a test is looking at it.
                try await Fixtures.writeM4A(
                    to: folder.appendingPathComponent(String(format: "%02d - %@.m4a", index + 1, song)),
                    tags: tags, seconds: 90
                )
            }
        }
        return root
    }
}
