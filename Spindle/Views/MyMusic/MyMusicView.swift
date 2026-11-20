import SwiftUI

/// The library: filter chips, sort, grid/list switch, and the content they select.
struct MyMusicView: View {
    @Environment(LibraryViewModel.self) private var library

    var body: some View {
        if library.isLibraryEmpty {
            EmptyLibraryView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    controls
                    content
                }
                .padding(.horizontal, Theme.pageInset)
                .padding(.top, 26)
                .padding(.bottom, 32)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My Music")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
            Text(library.summary)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder private var controls: some View {
        @Bindable var library = library
        HStack(spacing: 10) {
            ForEach(LibraryViewModel.Filter.allCases) { filter in
                FilterChip(title: filter.rawValue, isSelected: library.filter == filter) {
                    library.filter = filter
                }
            }
            Spacer()
            if library.filter == .all {
                SortMenu(options: LibraryViewModel.Sort.allCases, selection: $library.sort)
            }
            LayoutToggle(layout: $library.layout)
        }
    }

    @ViewBuilder private var content: some View {
        if library.hasNoResults {
            NoResultsView(query: library.searchText)
        } else {
            switch (library.layout, library.filter) {
            case (.grid, .artists):
                ArtistGrid(artists: library.visibleArtists)
            case (.grid, _):
                AlbumGrid(albums: library.visibleAlbums)
            case (.list, _):
                TrackListView(tracks: library.visibleTracks, context: "My Music")
            }
        }
    }
}

// MARK: - Grids

struct AlbumGrid: View {
    let albums: [Album]

    var body: some View {
        LazyVGrid(columns: cardColumns, spacing: 30) {
            ForEach(albums) { AlbumCard(album: $0) }
        }
    }
}

struct ArtistGrid: View {
    let artists: [ArtistGroup]

    var body: some View {
        LazyVGrid(columns: cardColumns, spacing: 30) {
            ForEach(artists) { ArtistCard(artist: $0) }
        }
    }
}

let cardColumns = [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 26, alignment: .top)]

/// Cover with a title and subtitle underneath; a play button fades in on hover.
struct CoverCard<Cover: View, Menu: View>: View {
    let title: String
    let subtitle: String
    let open: () -> Void
    let play: () -> Void
    @ViewBuilder let cover: () -> Cover
    @ViewBuilder let menu: () -> Menu

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover()
                .overlay(alignment: .bottomTrailing) {
                    Button(action: play) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .accentGlass(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .opacity(isHovering ? 1 : 0)
                    .offset(y: isHovering ? 0 : 6)
                    .allowsHitTesting(isHovering)
                    .help("Play")
                    .accessibilityLabel("Play \(title)")
                }
                .shadow(color: .black.opacity(0.35), radius: isHovering ? 16 : 8, y: isHovering ? 8 : 4)
                .scaleEffect(isHovering ? 1.015 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .onHover { isHovering = $0 }
        .animation(.smooth(duration: 0.18), value: isHovering)
        .contextMenu { menu() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Play", play)
        .accessibilityAction(.default, open)
    }
}

struct AlbumCard: View {
    let album: Album
    @Environment(AppViewModel.self) private var app
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        CoverCard(
            title: album.title,
            subtitle: album.year.map { "\(album.artist) \u{00B7} \($0)" } ?? album.artist,
            open: { app.navigate(to: .album(album.id)) },
            play: { player.play(album.tracks, context: album.title) }
        ) {
            ArtworkView(key: album.artworkKey, pixelSize: 512, cornerRadius: 12)
        } menu: {
            CollectionMenu(tracks: album.tracks, context: album.title)
            Divider()
            Button("Edit Album\u{2026}") { app.edit(album) }
        }
    }
}

struct ArtistCard: View {
    let artist: ArtistGroup
    @Environment(AppViewModel.self) private var app
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        CoverCard(
            title: artist.name,
            subtitle: "\(TimeFormat.count(artist.albums.count, "album")) \u{00B7} \(TimeFormat.count(artist.trackCount, "track"))",
            open: { app.navigate(to: .artist(artist.id)) },
            play: { player.play(artist.tracks, context: artist.name) }
        ) {
            ArtworkView(key: artist.artworkKey, pixelSize: 512, cornerRadius: 12)
        } menu: {
            CollectionMenu(tracks: artist.tracks, context: artist.name)
        }
    }
}

/// Context menu shared by albums, artists and playlists-from-tracks.
struct CollectionMenu: View {
    let tracks: [Track]
    let context: String
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        Button("Play") { player.play(tracks, context: context) }
        Button("Shuffle") { player.play(tracks, context: context, shuffled: true) }
        Divider()
        Button("Play Next") { player.playNext(tracks) }
        Button("Add to Queue") { player.addToQueue(tracks) }
        Divider()
        AddToPlaylistMenu(tracks: tracks)
    }
}

// MARK: - Empty states

struct NoResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.muted)
            Text(query.isEmpty ? "Nothing here yet" : "No results for \u{201C}\(query)\u{201D}")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Try a different spelling, or search by artist or album.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// First launch: an inviting prompt instead of an empty grid.
struct EmptyLibraryView: View {
    @Environment(AppViewModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle = 0.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .frame(width: 288, height: 288)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 222, height: 222)
                VinylDisc()
                    .frame(width: 158, height: 158)
                    .rotationEffect(.degrees(angle))
            }
            .padding(.bottom, 34)

            Text("Your library is empty")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.text)

            Text("Add MP3, FLAC, M4A or WAV files from your Mac to start listening. No accounts, no streaming \u{2014} just your music.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 500)
                .padding(.top, 10)

            Button { app.presentAddMusic() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 17, weight: .bold))
                    Text("Add music").font(.system(size: 17, weight: .semibold))
                }
                .padding(.horizontal, 12)
            }
            .buttonStyle(AccentButtonStyle(height: 56))
            .padding(.top, 28)

            Text("or drop files anywhere in this window")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 16)

            HStack(spacing: 8) {
                ForEach(["MP3", "FLAC", "M4A", "WAV"], id: \.self) { format in
                    Text(format)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
                }
            }
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
