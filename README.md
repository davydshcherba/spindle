# Spindle

A minimal, customizable music player for your own files — macOS &amp; iOS. Built with SwiftUI.

This repository contains the macOS MVP: import local **mp3, m4a, flac and wav** files, browse them as albums or a
list, build playlists, and play them with media-key and Control Center support. No accounts, no streaming, no
third-party dependencies.

## Requirements

- macOS 15+, Xcode 26 (Swift 6 language mode)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — only to regenerate `Spindle.xcodeproj` from `project.yml`
  (`brew install xcodegen`). The generated project is checked in, so you can also just open it.

## Build, run, test

```sh
xcodegen generate                      # only after adding/removing files or editing project.yml
open Spindle.xcodeproj                 # ⌘R to run, ⌘U to test
xcodebuild -scheme Spindle -destination 'platform=macOS' test
```

The app is signed ad hoc ("Sign to Run Locally"); set a development team in Xcode to run it on other Macs.

## How it works

```
Spindle/
  Models/       Track, Playlist (SwiftData) · Album/ArtistGroup (derived) · PlayerItem (store-free snapshot)
  Services/     LibraryService   import files/folders, tags + artwork (AVFoundation / FLAC parser), playlists
                PlayerService    AVPlayer, queue, next/previous, seek, shuffle, repeat, volume
                NowPlayingService  MPNowPlayingInfoCenter + MPRemoteCommandCenter (media keys, Control Center)
                ArtworkStore, SecurityScopedBookmark, DominantColor, …
  ViewModels/   @Observable view models — all UI logic lives here
  Views/        SwiftUI views — layout only, no business logic
  Platform/     the only AppKit: NSOpenPanel behind a `FilePicking` protocol
  App/          composition root (AppEnvironment / AppModel) and the app entry point
```

Models, services and view models have no unconditional AppKit dependency (the one platform image conversion in
`NowPlayingService` sits behind `#if canImport(AppKit)` / `UIKit`), so they can be reused for an iOS target; only
`Platform/` and the window chrome in `Views/` are macOS-specific.

### Sandbox and "remember my library"

The app is sandboxed with user-selected **read-only** file access plus the app-scope **bookmarks** entitlement
(`Config/Spindle.entitlements`). Every imported file gets a security-scoped bookmark stored on its `Track`, so the
library loads on the next launch and plays without asking again. Bookmarks are resolved lazily when a track is played,
and refreshed if the system reports them stale.

### Debug launch options

Debug builds only (compiled out of Release): set `SPINDLE_SEED_DIR` to import a folder on launch and
`SPINDLE_SCREEN` (e.g. `list,play`, `nowplaying`, `queue`, `add`) to start on a given screen. See
`Spindle/App/DebugLaunch.swift`. The sandboxed app can only read the seed folder if it lives inside its container.

## Not in the MVP

The turntable "vinyl" Now Playing variant from the design, light theme, gapless playback, editing tags, and iOS UI.
