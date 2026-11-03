# Aurora

> A beautiful, offline-first anime franchise tracker built with Flutter. Track what you watch across entire franchises, with data from AniList and MyAnimeList, a Persian (RTL) interface, and everything stored locally on your device.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![State](https://img.shields.io/badge/State-Riverpod-5C2D91?logo=riverpod&logoColor=white)

> Note: this is the original Aurora tracker (v1). It has been superseded by [AuroraList](https://github.com/GoldenTitab/AuroraList) (v2), which is the current, actively developed version. This repository is kept as the original implementation.

## Overview

Aurora combines two data sources, AniList and MyAnimeList (via Jikan), so that search and metadata still work when one source is missing an entry or is temporarily down. Your library lives in a local Hive database: no account is required, and the app works offline.

Instead of tracking single titles in isolation, Aurora groups seasons, movies, OVAs and spin-offs under one franchise, so you can see the whole story, track progress across it, and jump back into the next episode you were watching.

## Features

- **Franchise-based library** — group seasons, movies, OVAs and specials under one franchise, with a franchise tree, type folders and manual links between entries.
- **Accurate progress tracking** — franchise progress bars count only released entries, so unreleased titles do not distort your progress.
- **Continue watching** — jump straight back into the next episode of whatever you were watching.
- **Weekly airing calendar** — see which shows air on which day of the week.
- **New-episode notifications** — local notifications powered by background tasks.
- **Dual-API search** — search AniList and MyAnimeList / Jikan together, with a MyAnimeList fallback search when AniList has no result.
- **Statistics dashboard** — an overview of your watching habits and totals, including watch-time estimates.
- **Duplicate merge** — detect and merge duplicate entries.
- **Backup, restore and device transfer** — export your library and import it on another device.
- **PDF report** — generate and print or share a PDF summary of your library.
- **Android home-screen widget** — glanceable info without opening the app.
- **Theming** — dark-first design with a light theme and a customizable accent color.
- **Persian (RTL) UI** — designed right-to-left from the ground up.
- **Offline-first** — local storage with Hive, and cached artwork.

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | Flutter / Dart `^3.12.2` |
| State management | `flutter_riverpod` 2.6.1 |
| Local storage | `hive` + `hive_flutter` |
| Data sources | AniList, MyAnimeList, [Jikan](https://jikan.moe) |
| Notifications | `flutter_local_notifications`, background tasks with `workmanager` |
| Navigation | `go_router` (declarative routing) |
| Tooling | `flutter_lints`, `flutter_launcher_icons`, `flutter_native_splash` |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.12.2 or newer
- Android Studio or VS Code with the Flutter extension
- An Android device or emulator (physical devices work well with USB debugging)

### Installation

```bash
git clone https://github.com/GoldenTitab/Aurora.git
cd Aurora
flutter pub get
```

Check your setup first:

```bash
flutter doctor
```

### Run

```bash
flutter run
```

### Optional: regenerate icons and splash screen

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Build a release APK

```bash
flutter build apk --release
```

The output will be at `build/app/outputs/flutter-apk/app-release.apk`. For split APKs per ABI:

```bash
flutter build apk --release --split-per-abi
```

## Project Structure

The project follows a standard Flutter layout, with the UI, state, data clients and local storage kept separate:

- **State:** Riverpod providers expose the library, search and settings state to the UI; widgets rebuild only when the data they watch changes.
- **Persistence:** Hive boxes store the user's library, franchise links and settings locally, which also powers backup and restore.
- **Data layer:** API clients for AniList, MyAnimeList and Jikan are kept separate from UI code, so one source can fail or be replaced without affecting the rest of the app.
- **Routing:** declarative navigation with `go_router`.
- **Background tasks:** `workmanager` periodically checks for new episodes and triggers local notifications.

## Usage

Search for a title, add its franchise to your library, track episodes as you watch them, and use Continue Watching to pick up where you left off. The weekly calendar shows what airs on each day, and the statistics dashboard summarizes your watching habits.

## Roadmap

- iOS polish and testing
- Cloud sync (optional account)
- English and additional UI languages
- More statistics and export formats
- Automated tests and CI

## Contributing

Please run `flutter analyze` before submitting a pull request.

## License

No license file is present in this repository.
