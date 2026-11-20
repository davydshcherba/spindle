import Foundation
import Testing
@testable import Spindle

@MainActor
struct MetadataReaderTests {
    private let reader = MetadataReader()
    private let tags = FixtureTags(
        title: "Glass Rooms", artist: "Maren Volk", albumArtist: "Maren Volk",
        album: "Low Tide Hours", track: 3, year: 2024
    )

    private func scratch() throws -> URL { try Fixtures.makeScratchDirectory() }

    @Test func readsM4ATagsAndArtwork() async throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var tags = tags
        tags.cover = try Fixtures.coverJPEG(red: 0.9, green: 0.4, blue: 0.1)
        let url = dir.appending(path: "song.m4a")
        try await Fixtures.writeM4A(to: url, tags: tags)

        let metadata = await reader.read(from: url)

        #expect(metadata.title == "Glass Rooms")
        #expect(metadata.artist == "Maren Volk")
        #expect(metadata.albumArtist == "Maren Volk")
        #expect(metadata.album == "Low Tide Hours")
        #expect(metadata.trackNumber == 3)
        #expect(metadata.year == 2024)
        #expect(abs(metadata.duration - 2) < 0.25)
        #expect(metadata.artworkData?.isEmpty == false)
    }

    @Test func readsFLACTagsAndArtwork() async throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var tags = tags
        tags.cover = try Fixtures.coverJPEG(red: 0.1, green: 0.5, blue: 0.9)
        let url = dir.appending(path: "song.flac")
        try Fixtures.writeFLAC(to: url, tags: tags)

        let metadata = await reader.read(from: url)

        #expect(metadata.title == "Glass Rooms")
        #expect(metadata.artist == "Maren Volk")
        #expect(metadata.album == "Low Tide Hours")
        #expect(metadata.trackNumber == 3)
        #expect(metadata.year == 2024)
        #expect(abs(metadata.duration - 2) < 0.1)
        #expect(metadata.artworkData?.isEmpty == false)
    }

    @Test func readsMP3TagsAndArtwork() async throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var tags = tags
        tags.cover = try Fixtures.coverJPEG(red: 0.4, green: 0.8, blue: 0.2)
        let url = dir.appending(path: "song.mp3")
        try Fixtures.writeMP3(to: url, tags: tags)

        let metadata = await reader.read(from: url)

        #expect(metadata.title == "Glass Rooms")
        #expect(metadata.artist == "Maren Volk")
        #expect(metadata.albumArtist == "Maren Volk")
        #expect(metadata.album == "Low Tide Hours")
        #expect(metadata.trackNumber == 3)
        #expect(metadata.year == 2024)
        #expect(abs(metadata.duration - 2) < 0.3)
        #expect(metadata.artworkData?.isEmpty == false)
    }

    @Test func untaggedWAVHasDurationButNoTags() async throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "01 - Untitled Demo.wav")
        try Fixtures.writeWAV(to: url)

        let metadata = await reader.read(from: url)

        #expect(metadata.title == nil)
        #expect(metadata.artist == nil)
        #expect(abs(metadata.duration - 2) < 0.1)
    }

    @Test func garbageFileReportsNoDuration() async throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "broken.mp3")
        try Data("this is not audio".utf8).write(to: url)

        let metadata = await reader.read(from: url)

        #expect(metadata.duration == 0)
    }

    @Test(arguments: [
        ("01 - Glass Rooms.flac", "Glass Rooms"),
        ("07. Slow Orbit.mp3", "Slow Orbit"),
        ("Plain Name.m4a", "Plain Name"),
        ("2024.wav", "2024"),
    ])
    func filenameFallbackStripsTrackNumbers(filename: String, expected: String) {
        #expect(TagParsing.title(fromFilename: URL(fileURLWithPath: "/tmp/\(filename)")) == expected)
    }
}
