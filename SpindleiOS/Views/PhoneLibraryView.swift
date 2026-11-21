import SwiftUI

/// The My Music tab: your songs, albums and artists, with search, sorting, and a way to add more.
struct PhoneLibraryView: View {
    @Environment(LibraryViewModel.self) private var library
    @Environment(ImportViewModel.self) private var importer
    @Environment(PhoneNavigator.self) private var navigator

    @State private var isSettingsPresented = false
    @State private var didChooseDefaultSort = false

    /// What the segmented control offers, and the library filter and layout each one means.
    private enum Section: String, CaseIterable, Identifiable {
        case songs = "Songs", albums = "Albums", artists = "Artists", recent = "Recent"

        var id: Self { self }
        var filter: LibraryViewModel.Filter {
            switch self {
            case .songs: .all
            case .albums: .albums
            case .artists: .artists
            case .recent: .recentlyAdded
            }
        }
        var layout: LibraryViewModel.Layout {
            switch self {
            case .songs, .recent: .list
            case .albums, .artists: .grid
            }
        }
    }

    private var section: Binding<Section> {
        Binding(
            get: { Section.allCases.first { $0.filter == library.filter && $0.layout == library.layout } ?? .songs },
            set: { library.filter = $0.filter; library.layout = $0.layout }
        )
    }

    var body: some View {
        @Bindable var library = library
        @Bindable var navigator = navigator

        NavigationStack(path: $navigator.libraryPath) {
            content
                .containerBackground(for: .navigation) { AmbientBackground() }
                .navigationTitle("My Music")
                // At the top (pull the list down), so the bottom is free for the mini player.
                .searchable(
                    text: $library.searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Songs, albums, artists"
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { isSettingsPresented = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) { sortMenu }
                    ToolbarItem(placement: .topBarTrailing) { addMenu }
                }
                .navigationDestination(for: Route.self) { PhoneDestination(route: $0) }
        }
        .sheet(isPresented: $isSettingsPresented) { PhoneSettingsView() }
        .onAppear {
            // Alphabetical reads best on a small screen.
            guard !didChooseDefaultSort else { return }
            didChooseDefaultSort = true
            library.sort = .title
        }
    }

    @ViewBuilder private var content: some View {
        if library.isLibraryEmpty {
            PhoneEmptyLibrary()
        } else {
            VStack(spacing: 0) {
                Picker("Show", selection: section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                if library.hasNoResults {
                    ContentUnavailableView.search(text: library.searchText)
                } else {
                    switch section.wrappedValue {
                    case .songs: PhoneTrackList(tracks: library.visibleTracks, context: "My Music")
                    case .recent: PhoneTrackList(tracks: library.visibleTracks, context: "Recently added")
                    case .albums: PhoneAlbumGrid(albums: library.visibleAlbums)
                    case .artists: PhoneArtistList(artists: library.visibleArtists)
                    }
                }
            }
        }
    }

    // MARK: Toolbar

    @ViewBuilder private var sortMenu: some View {
        @Bindable var library = library
        // Sorting applies to the full song list; the other sections have an order of their own.
        if section.wrappedValue == .songs {
            Menu {
                Picker("Sort by", selection: $library.sort) {
                    ForEach(LibraryViewModel.Sort.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort")
        }
    }

    private var addMenu: some View {
        Menu {
            Button { Task { await importer.chooseFiles() } } label: {
                Label("Add songs\u{2026}", systemImage: "music.note")
            }
            Button { Task { await importer.chooseFolder() } } label: {
                Label("Add a folder\u{2026}", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add music")
    }
}

// MARK: - Albums and artists

private struct PhoneAlbumGrid: View {
    let albums: [Album]

    private let columns = [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(albums) { PhoneAlbumCard(album: $0) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }
}

private struct PhoneAlbumCard: View {
    let album: Album
    @Environment(AppViewModel.self) private var app

    var body: some View {
        NavigationLink(value: Route.album(album.id)) {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(key: album.artworkKey, pixelSize: 512, cornerRadius: 12)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(album.year.map { "\(album.artist) \u{00B7} \($0)" } ?? album.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            CollectionMenu(tracks: album.tracks, context: album.title)
            Divider()
            Button("Edit Album\u{2026}") { app.edit(album) }
        }
    }
}

private struct PhoneArtistList: View {
    let artists: [ArtistGroup]

    var body: some View {
        List(artists) { artist in
            NavigationLink(value: Route.artist(artist.id)) {
                HStack(spacing: 14) {
                    ArtworkView(key: artist.artworkKey, pixelSize: 128, cornerRadius: 28)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text("\(TimeFormat.count(artist.albums.count, "album")) \u{00B7} \(TimeFormat.count(artist.trackCount, "track"))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Theme.hairline)
            .contextMenu { CollectionMenu(tracks: artist.tracks, context: artist.name) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Empty

struct PhoneEmptyLibrary: View {
    @Environment(ImportViewModel.self) private var importer

    var body: some View {
        VStack(spacing: 14) {
            VinylDisc()
                .frame(width: 128, height: 128)
                .padding(.bottom, 10)
            Text("Your library is empty")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Add MP3, FLAC, M4A or WAV files from the Files app. No accounts, no streaming \u{2014} just your music.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Button { Task { await importer.chooseFiles() } } label: {
                Label("Add music", systemImage: "plus")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(AccentButtonStyle(height: 50))
            .padding(.top, 10)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
