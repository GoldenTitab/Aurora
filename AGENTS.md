# AGENTS.md — Aurora

Flutter app (Android-first, also `ios/`) — offline-first anime **franchise** tracker. UI is Persian (RTL) by default with an English mode. Flutter 3.44.6 stable / Dart 3.12.2.

## Commands

```bash
flutter pub get
flutter analyze          # PR gate (README). Exits 1 on ANY diagnostic, incl. infos.
flutter test             # 62 tests, all pass, ~2s
flutter test test/franchise_root_test.dart            # one file
flutter test test/bulk_import_parser_test.dart --plain-name "confident"  # one case
flutter build apk --release                           # build/app/outputs/flutter-apk/app-release.apk  (~30s warm, ~440s clean)
flutter build appbundle --release                     # build/app/outputs/bundle/release/app-release.aab
dart run flutter_launcher_icons                       # after editing assets/icon/
dart run flutter_native_splash:create                 # after editing assets/icon/
```

- **Baseline is currently red:** `flutter analyze` exits 1 on one pre-existing info — `curly_braces_in_flow_control_structures` at `lib/features/rewards/rewards_screen.dart:337`. Don't mistake it for your own breakage; `flutter analyze --no-fatal-infos` exits 0.
- No CI, no pre-commit hooks, no task runner (no `.github/`). `flutter analyze` + `flutter test` is the whole gate.
- `analysis_options.yaml` is stock `flutter_lints`; `build/**`, `android/**`, `ios/**` are excluded from analysis.
- Release artifacts are **debug-signed** (see Android specifics) — `apksigner verify` will report `CN=Android Debug`.

## Config
- Kilo project config: `.kilo/command/*.md`, `.kilo/agent/*.md`, `kilo.json`, `AGENTS.md`. Put new commands/agents in `.kilo/`. **Do not** use `.kilocode/` or `.opencode/`.
- Global: `C:\Users\APPLE DOOR\.config\kilo/` (same structure). If config questions arise, load skill `kilo-config`.

## Architecture

`lib/main.dart` opens **all Hive boxes before** `runApp(ProviderScope(...))`. Several providers read Hive synchronously inside `build()` (`dataSaverProvider`, `searchHistoryProvider`, `watchStorageProvider`, `userExtrasProvider`, `franchiseRepositoryProvider`) — a new box must be added to the `_openBox` list in `main.dart` or those providers throw.

| Path | Owns |
| --- | --- |
| `lib/core/` | theme, i18n, router, utils, shared widgets |
| `lib/data/models/` | plain data classes + `fromJson`/`toJson` |
| `lib/data/remote/` | API clients, all behind `ApiGateway` |
| `lib/data/repository/` | franchise graph building & caching |
| `lib/data/storage/` | Hive boxes, migrations, export/reset |
| `lib/data/providers/` | Riverpod providers — **10 files, re-exported by the barrel `lib/data/providers.dart`**; import providers from `package:aurora/data/providers.dart` |
| `lib/data/gamification/` `notifications/` `homewidget/` | economy+cards, workmanager+notifications, home-screen widget |
| `lib/features/<name>/` | one screen per feature + a local `widgets/` subfolder |

- No code generation: no `build_runner`, no `.g.dart`, no `freezed`. Riverpod v2 `Notifier`/`NotifierProvider`/`FutureProvider`/`StreamProvider`, hand-written.
- Routing is `go_router` in `lib/core/router/app_router.dart`: a 5-branch `StatefulShellRoute` (discover / search / list / profile / settings) plus root-level full-screen routes. A redirect gate forces `/onboarding` until `app_meta['onboarding_done'] == '1'`.
- **Build franchise routes with `franchiseRouteFor(anilistId, entryId)`** (`lib/core/utils/route_utils.dart`) — never hand-build `/franchise/...`; the MAL variant is `/franchise/mal-<id>`.

## Storage (Hive) — everything is a `Box<String>`

Values are stored as **strings**; objects are JSON-encoded manually. Box names live in `Boxes` (`lib/data/storage/migrations.dart:7`); `card_cache`, `discover_cache`, `home_cache` are string literals used in several places.

- `franchise_cache` keys: `f:<franchiseId>` = franchise JSON, `a:<entryId>` = the franchise id it aliases to.
- `app_meta` keys are **prefixed by domain**: `note:`, `enote:`, `uscore:`, `frating:`, `seen:`, `wo:`, `sh:`, `stat:`, `mx:`, `ach:`, `mission_claimed:`, `card:`, `cardinfo:`, `manual_entries:`, `manual_pos:`, `manual_note:`, `heat:`, `xpep:`, `frdone:`, `notif_aired:`, `dismissed_new_ep`.
- **When you add a new user-data meta key, also add it to `DataReset._metaUserKeys` / `_metaUserPrefixes`** (`lib/data/storage/data_reset.dart:6,30`) — otherwise "delete all data" silently leaves it behind. `test/data_reset_test.dart` pins this contract.
- Changing the persisted shape requires bumping `Migrations.currentVersion` (`lib/data/storage/migrations.dart:33`) and adding a `_vN()` step. `Migrations.run()` auto-backs-up user data first (keeps max 3) and writes `schema_version` to `app_meta`; a failed migration is non-fatal and is logged to `app_meta['migration_error']`.
- Entry ids are `al-<anilistId>` / `mal-<malId>` throughout models, cache keys and routes.

## i18n / RTL — no Flutter localization delegates

- `tr('key', [args])` is a **global function** (`lib/core/i18n/lang.dart:11`) backed by the `kFa` / `kEn` maps in `lib/core/i18n/strings.dart` (~1700 lines). `Locale` is set on `MaterialApp.router` but strings are resolved manually.
- New user-facing strings must exist in **both** `kFa` and `kEn`. Placeholders are `{0}`, `{1}`.
- `Lang.current` is a global (`'fa'` default). Switching language rebuilds the whole widget tree (`_rebuildAll` in `lib/app.dart:40`) — `Directionality` is applied there, not via `locale`.
- Latin→Persian digits are **not** automatic: call `toFa(value)` (`lib/core/utils/persian_numbers.dart:3`) explicitly wherever numbers are shown.

## Networking

`ApiGateway` (`lib/data/remote/api_gateway.dart`) is the only HTTP path. It owns per-host rate limiting (AniList 750 ms, MAL 400 ms, Jikan 1100 ms min gap), retry with backoff, `429`/`retry-after` handling, and a Hive response cache in `api_cache` (14 days / 400 entries; prune via `ApiGateway.pruneCache`).

- AniList = GraphQL POST `https://graphql.anilist.co`; MAL = REST v2 with an `X-MAL-CLIENT-ID` header (client id hard-coded in `lib/core/constants/app_config.dart:13`); Jikan = REST v4.
- Clients swallow errors and return empty results; user-facing failures go through `ApiException` + `friendlyError()`.
- Log with `kDebugMode`-guarded `debugPrint` (API logs are prefixed `[API]`).
- `dart:io` is used directly (`IOClient`/`HttpClient`) — the app is **not web-buildable**; don't reach for web targets. 
- **MAL client ID** lives in `lib/core/constants/app_config.dart:13` (hard-coded). Never commit a new client ID; if you change it locally, don't push.

## Android specifics

- **Toolchain matrix is pinned to Flutter 3.44.6's own supported set — don't "upgrade" it ad hoc.** Flutter 3.44.6's `DependencyVersionChecker` warns below Gradle 8.14.0 / AGP 8.11.1 / KGP 2.2.20, and `packages/flutter_tools/gradle/build.gradle.kts` compiles against AGP 8.11.1 + Kotlin 2.2.20. The project matches exactly: Gradle wrapper 8.14.3, AGP 8.11.1, Kotlin 2.2.20, Java 17 source/target, `jvmTarget = JVM_17`.
- `android/app/build.gradle.kts`: **release builds use the debug signing config** (`signingConfig = signingConfigs.getByName("debug")`) — release APKs/AABs are debug-signed, not production-signed. Don't "fix" this without a real keystore.
- `android/settings.gradle.kts` lists **Aliyun maven mirrors before `google()`/`mavenCentral()`**. Keep them if you build behind those mirrors. The `resolutionStrategy { eachPlugin { ... } }` block is deliberately written without an `all { }` wrapper.
- `android/gradle.properties`: the Gradle daemon is **enabled** and `org.gradle.parallel=false` / `workers.max=2` are kept for the memory-constrained machine. Repeat release builds take ~30 s warm vs ~440 s clean; if the daemon is disabled you'll pay a JVM fork every time. `kotlin.jvm.target.validation.mode` is deliberately **left at Kotlin's default (`error`)** — the old `warning` override was a workaround for a `home_widget` Java 1.8 / Kotlin 17 mismatch that no longer applies.
- `flutter build` picks its JDK from `flutter config --jdk-dir` → **Android Studio's bundled JBR** → `JAVA_HOME` → `java` on PATH (`packages/flutter_tools/lib/src/android/java.dart`). A bare `android\gradlew.bat` invocation instead uses `JAVA_HOME`. Both JDK 21 LTS work, but they spawn *separate* Gradle daemons.
- **Do not re-add a `force("androidx.glance:...")` pin.** `home_widget` 0.10.0 compiles against Glance **1.2.0** (`setWidgetPreviews` only exists in 1.2.0+); pinning the app to 1.1.1 shipped a Glance 1.1.1 runtime under 1.2.0-compiled bytecode. Let the plugin declare its own version and check `META-INF/androidx.glance_glance.version` inside the APK/AAB.
- Version is duplicated: `pubspec.yaml` `version:` and `kAppVersion` in `lib/core/constants/app_config.dart:15` — bump both.

## Windows network / proxy

- **No proxy is configured** in this environment: no `HTTP(S)_PROXY`/`NO_PROXY` env vars (the `http_proxy`/`https_proxy` user values are empty strings, which Dart treats as unset), no `http.proxy` in git config, `ProxyEnable=0` in WinINET, no `~/.gradle/gradle.properties`. Direct connectivity to GitHub / pub.dev / Google Maven / Maven Central / services.gradle.org all work.
- A **live proxy is listening on `127.0.0.1:10808`** (speaks both SOCKS5 and HTTP CONNECT). It is *not* visible in `Get-NetTCPConnection -State Listen`, so don't conclude it's absent from that output alone.
- A user-scoped `no_proxy` / `NO_PROXY` = `localhost,127.0.0.1,::1` is persisted in `HKCU\Environment`. **Keep it.** Without it, enabling `HTTP_PROXY` sends Dart's `HttpClient` — the same client the Flutter tool uses for the VM service — through the proxy, which cannot reach the client's own loopback: the VM service then fails (503/timeout) while external hosts still work. Dart matches `no_proxy` by suffix (`url.host.endsWith(name)`), and reads `no_proxy` before `NO_PROXY`.
- `http://` vs `https://` proxy vars are separate in Dart; set both if you ever need to route through the proxy.

## Testing conventions

- Pure-logic unit tests only: no widget tests, no golden/snapshot tests, and **no mocking library** (no mockito/mocktail in dev_dependencies). Testable logic is extracted out of widgets into static/pure functions for exactly this reason (e.g. `FranchiseRepository.pickRootId`).
- Hive-dependent tests open boxes on a temp dir: `Directory.systemTemp.createTemp('aurora_*_test_')` → `Hive.init(dir.path)` → `Hive.openBox<String>(name)` in `setUpAll`, `Hive.close()` in `tearDownAll`, `setUp(clearAll)` between tests. See `test/backup_restore_test.dart`.
- **Test names and doc comments are in Persian** — match that when adding tests.
- The backup test needs a ~2 ms delay between imports: backup keys are derived from `millisecondsSinceEpoch` and must stay unique.
- Card rarity weights must total exactly 10000 (`test/card_acquisition_test.dart`).

## Style / conventions

- snake_case filenames; providers are camelCase `xxxProvider`; feature widgets live in that feature's `widgets/` folder, shared ones in `lib/core/widgets/`.
- **Code comments and test descriptions are written in Persian**; identifiers and code are English.
- `try { ... } catch (_) {}` with an empty body is a deliberate, widespread pattern here (startup, widget refresh, storage writes) — don't "fix" it into a crash.
- `setState` for local widget state, providers for app state; screens read data via `ref.watch(...)`.
- End with `flutter analyze` + `flutter test` before handing work back. Baseline analyze is already failing on one unrelated lint (see Commands).
