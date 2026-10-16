
<div align="center">

# Aurora

**A beautiful, offline-first anime franchise tracker built with Flutter.**

Track what you watch across entire franchises — seasons, movies, OVAs and spin-offs — with data from AniList, MyAnimeList and Jikan, a Persian (RTL) interface, and everything stored locally on your device.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![State](https://img.shields.io/badge/State-Riverpod-5C2D91)
![Version](https://img.shields.io/badge/version-1.1.0-8A5CF6)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Build a Release APK](#build-a-release-apk)
- [Project Structure](#project-structure)
- [Architecture Notes](#architecture-notes)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

---

## Overview

Most trackers treat every season, movie and OVA as an unrelated entry. **Aurora** groups them into **franchises**, so you can see your real progress through a whole series at a glance — what you've finished, what's airing, and what to watch next.

Aurora combines two data sources (AniList and MyAnimeList via Jikan) so that search and metadata still work when one of them is missing an entry or is temporarily down. Your library lives in a local Hive database: no account required, and it works offline.

## Features

- **Franchise-based library** — group seasons, movies, OVAs and specials under one franchise, with a franchise tree, type folders and manual links between entries.
- **Accurate progress tracking** — franchise progress bars count only released entries, so unreleased titles don't distort your progress.
- **Continue watching** — jump straight back into the next episode of whatever you were watching.
- **Weekly airing calendar** — see which shows air on which day of the week.
- **New-episode notifications** — local notifications powered by background tasks.
- **Dual-API search** — search AniList and MyAnimeList/Jikan together, with MAL fallback search when AniList has no result.
- **Statistics dashboard** — overview of your watching habits and totals, including watch-time estimates.
- **Duplicate merge** — detect and merge duplicate entries.
- **Backup, restore & device transfer** — export your library and import it on another device.
- **PDF report** — generate and print/share a PDF summary of your library.
- **Android home-screen widget** — glanceable info without opening the app.
- **Theming** — dark-first design with a light theme and a customizable accent color.
- **Persian (RTL) UI** — designed right-to-left from the ground up.
- **Offline-first** — local storage with Hive; cached artwork via `cached_network_image`.

> Some features listed above may still be rolling out — see the [Roadmap](#roadmap).

## Tech Stack

| Area | Technology |
| --- | --- |
| Framework | [Flutter](https://flutter.dev) / Dart `^3.12.2` |
| State management | [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) `2.6.1` |
| Navigation | [`go_router`](https://pub.dev/packages/go_router) |
| Local storage | [`hive`](https://pub.dev/packages/hive) + [`hive_flutter`](https://pub.dev/packages/hive_flutter) |
| Networking | [`http`](https://pub.dev/packages/http) |
| Data sources | AniList, MyAnimeList, [Jikan](https://jikan.moe) |
| Notifications | [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) |
| Background work | [`workmanager`](https://pub.dev/packages/workmanager) |
| Home widget | [`home_widget`](https://pub.dev/packages/home_widget) |
| PDF export | [`pdf`](https://pub.dev/packages/pdf) + [`printing`](https://pub.dev/packages/printing) |
| Images | [`cached_network_image`](https://pub.dev/packages/cached_network_image) |
| Typography | [`google_fonts`](https://pub.dev/packages/google_fonts) |
| Filesystem | [`path_provider`](https://pub.dev/packages/path_provider) |
| Tooling | `flutter_lints`, `flutter_launcher_icons`, `flutter_native_splash` |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart `3.12.2` or newer
- Android Studio or VS Code with the Flutter extension
- An Android device or emulator (physical devices work great with USB debugging)

Verify your setup:

```bash
flutter doctor
```

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/GoldenTitab/Aurora.git
cd Aurora

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Optional: regenerate icons and splash screen

The launcher icon and native splash are configured in `pubspec.yaml`. If you change the assets in `assets/icon/`, regenerate them with:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Build a Release APK

```bash
flutter build apk --release
```

The output will be at `build/app/outputs/flutter-apk/app-release.apk`.

To build smaller, per-architecture APKs:

```bash
flutter build apk --release --split-per-abi
```

## Project Structure

```text
Aurora/
├── android/          # Android platform project
├── ios/              # iOS platform project (Runner)
├── assets/
│   └── icon/         # App icon and splash assets
├── lib/              # Application source code (Dart)
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Architecture Notes

- **State:** Riverpod providers expose the library, search and settings state to the UI; widgets rebuild only when the data they watch changes.
- **Persistence:** Hive boxes store the user's library, franchise links and settings locally, which also powers backup/restore.
- **Data layer:** API clients for AniList, MyAnimeList and Jikan are kept separate from UI code, so one source can fail or be replaced without affecting the rest of the app.
- **Routing:** Declarative navigation with `go_router`.
- **Background tasks:** `workmanager` periodically checks for new episodes and triggers local notifications.

## Roadmap

- [ ] iOS polish and testing
- [ ] Cloud sync (optional account)
- [ ] English and additional UI languages
- [ ] More statistics and export formats
- [ ] Automated tests and CI

## Contributing

Contributions, issues and feature requests are welcome.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push the branch: `git push origin feature/my-feature`
5. Open a Pull Request

Please run `flutter analyze` before submitting a PR.

## Author

**Ali D. Shah** — UI/UX designer & Flutter developer
GitHub: [@GoldenTitab](https://github.com/GoldenTitab)

## License

No license has been specified yet. Until a `LICENSE` file is added, all rights are reserved by the author.

---

<div align="center">
Made with Flutter and a lot of anime.
</div>
