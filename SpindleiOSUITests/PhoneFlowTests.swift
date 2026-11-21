import XCTest

/// What a person does on the phone: browse, play, queue, edit, make a playlist.
final class PhoneFlowTests: PhoneUITestCase {
    // MARK: Browsing

    @MainActor func testSongsAlbumsAndArtistsAreListed() {
        XCTAssertTrue(songRow("Undertow").exists)

        showSection("Albums")
        XCTAssertTrue(element(containing: "Low Tide Hours").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Paper Lanterns").exists)
        XCTAssertTrue(element(containing: "Field Notes").exists)

        showSection("Artists")
        XCTAssertTrue(element(containing: "Maren Volk").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Teo Brannigan").exists)
    }

    @MainActor func testAnAlbumPageListsItsSongs() {
        showSection("Albums")
        element(containing: "Low Tide Hours").tap()

        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Shuffle"].exists)
        XCTAssertTrue(songRow("Glass Rooms").exists)
        XCTAssertTrue(songRow("Undertow").exists)
        XCTAssertFalse(songRow("Lantern Song").exists, "another album's song must not be here")
    }

    @MainActor func testSearchNarrowsTheList() {
        let search = app.searchFields.firstMatch
        if !search.exists { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("lantern")

        XCTAssertTrue(songRow("Lantern Song").waitForExistence(timeout: 5))
        XCTAssertFalse(songRow("Undertow").exists)
    }

    @MainActor func testThePlaylistsTabShowsTheSamplePlaylists() {
        showTab("Playlists")
        XCTAssertTrue(element(containing: "Gym Rotation").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "New playlist").exists)
    }

    // MARK: Playing

    @MainActor func testPlayingASongOpensTheMiniPlayerAndTheFullPlayer() {
        songRow("Glass Rooms").tap()

        let miniPlayer = app.buttons["Open player"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10), "the mini player never appeared")
        XCTAssertEqual(miniPlayer.value as? String, "Glass Rooms, Maren Volk")
        XCTAssertTrue(app.buttons["Pause"].exists, "the song should be playing")

        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "pausing should offer Play")

        miniPlayer.tap()
        XCTAssertTrue(app.buttons["Queue"].waitForExistence(timeout: 5), "the full player never opened")
        XCTAssertTrue(app.buttons["Equalizer"].exists)
        XCTAssertTrue(app.buttons["Add to playlist"].exists)
        XCTAssertTrue(app.buttons["More"].exists)
    }

    @MainActor func testTheQueueShowsWhatIsNext() {
        songRow("Glass Rooms").tap()
        app.buttons["Open player"].tap()
        app.buttons["Queue"].tap()

        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Lantern Song").exists, "the next songs should be listed")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Queue"].waitForExistence(timeout: 5), "back on the player")
    }

    @MainActor func testSwipingASongToPlayItNextPutsItFirstInTheQueue() {
        songRow("Glass Rooms").tap()
        XCTAssertTrue(app.buttons["Open player"].waitForExistence(timeout: 10))

        // Songs are alphabetical, so Undertow is last; "Play Next" should bring it forward.
        songRow("Undertow").swipeRight()
        let playNext = app.buttons["Play Next"]
        XCTAssertTrue(playNext.waitForExistence(timeout: 5), "swiping right should offer Play Next")
        playNext.tap()

        app.buttons["Open player"].tap()
        app.buttons["Queue"].tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout: 5))
        let undertow = songRow("Undertow")
        let lantern = songRow("Lantern Song")
        XCTAssertTrue(undertow.waitForExistence(timeout: 5) && lantern.exists)
        XCTAssertLessThan(undertow.frame.minY, lantern.frame.minY, "Undertow should come before Lantern Song")
    }

    // MARK: Equalizer

    @MainActor func testPickingAnEqualizerPresetSwitchesItOn() {
        songRow("Glass Rooms").tap()
        app.buttons["Open player"].tap()
        app.buttons["Equalizer"].tap()

        let toggle = app.switches["Equalizer"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Preset")).firstMatch.tap()
        let rock = app.buttons["Rock"]
        XCTAssertTrue(rock.waitForExistence(timeout: 5))
        rock.tap()

        XCTAssertEqual(toggle.value as? String, "1", "choosing a preset should turn the equalizer on")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Preset: Rock")).firstMatch.exists)
    }

    // MARK: Playlists

    @MainActor func testAddingASongToANewPlaylist() {
        chooseFromMenu(of: songRow("Undertow"), "Add to Playlist")
        let newPlaylist = app.buttons["New Playlist\u{2026}"]
        XCTAssertTrue(newPlaylist.waitForExistence(timeout: 5))
        newPlaylist.tap()

        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Road Trip")
        app.buttons["Create"].tap()

        showTab("Playlists")
        XCTAssertTrue(element(containing: "Road Trip").waitForExistence(timeout: 5))
    }

    // MARK: Editing

    @MainActor func testEditingASongCanMoveItIntoAnExistingAlbum() {
        chooseFromMenu(of: songRow("Undertow"), "Edit Info\u{2026}")
        XCTAssertTrue(app.staticTexts["Edit info"].waitForExistence(timeout: 5))

        app.buttons["Choose an existing album"].tap()
        let lanterns = element(containing: "Paper Lanterns, The Quiet Arcade")
        XCTAssertTrue(lanterns.waitForExistence(timeout: 5), "the existing albums should be offered")
        lanterns.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Adds to")).firstMatch
                .waitForExistence(timeout: 5),
            "the editor should say the song joins an album that exists"
        )
        app.buttons["Save"].tap()

        XCTAssertTrue(songRow("Undertow").waitForExistence(timeout: 5))
        XCTAssertTrue(songRow("Undertow").label.contains("Paper Lanterns"), songRow("Undertow").label)
    }

    // MARK: Settings

    @MainActor func testSettingsShowsTheLibrarySize() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "4 tracks")).firstMatch.exists,
            "the library has four songs"
        )
        XCTAssertTrue(app.buttons["Remove all music\u{2026}"].exists)
    }
}
