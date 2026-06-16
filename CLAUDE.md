# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

综测活动记录软件 — a cross-platform (Android / iOS / Windows) Flutter app for quickly recording 综合素质测评 (comprehensive-quality-assessment) activities. **Local-first**: all data lives on-device. Two sync paths share one record-level merge engine: WebDAV (remote backup, online/offline) and a private LAN protocol (point-to-point, same Wi-Fi). UI is mobile-first (half-screen sheets for one-handed use). See `README.md` for the full product spec (in Chinese).

## Commands

```bash
flutter pub get                      # install deps
flutter analyze                      # static analysis (treat as the build gate — must be clean)
flutter test                         # run all tests
flutter test test/widget_test.dart  # run one test file
flutter test --plain-name "学年总分按分类上限截断"   # run a single test by name

flutter run -d chrome                # fastest way to preview (web; see web caveats below)
flutter run -d windows               # native; requires Visual Studio "Desktop development with C++"
flutter build web                    # produces build/web/
```

`flutter analyze` is the primary correctness gate here — it performs full type checking, so a clean analyze means the Dart compiles. Tests cover the scoring engine.

### Build/run environment caveats
- **Windows desktop** needs both Developer Mode ON (plugin symlinks) *and* Visual Studio with the C++ workload. Without VS the build fails with "Unable to find suitable Visual Studio toolchain".
- **Web** runs without extra toolchains and is the quickest preview, but `path_provider` and file/attachment APIs are unavailable there — storage falls back to `SharedPreferences` and attachments/WebDAV degrade to no-ops (see Storage below).

## Architecture

State management is **provider + ChangeNotifier**, set up in `lib/main.dart` (loads `AppState` + `SettingsState` before `runApp`). There is no codegen — JSON serialization is hand-written `toJson`/`fromJson` on each model.

### Layers
- `lib/models/` — plain data classes. `Template` is the central config: it owns `ActivityCategory` list (each with color/yearCap/hint), `awardLevels`, `ranks`, `roles`, a `distinguishRoles` flag, and a flat `ScoreRule` list. The year score cap is **derived**, not stored: `Template.yearScoreCap` = sum of all category `yearCap`s (set indirectly by editing category caps in the template editor). `AcademicYear` (name/archived/order only — no per-year cap), `ActivityRecord`, `Attachment` are the user data. `Template` / `AcademicYear` / `ActivityRecord` each carry an `updatedAt` for sync (see Sync below); `Tombstone` records deletions.
- `lib/state/app_state.dart` — the single source of truth for template + years + records (+ deletion tombstones). All mutations go through it and immediately persist via `StorageService`. `copyWith` bumps `updatedAt`, so route edits through `updateRecord`/`updateYear`; deletes write tombstones. `exportSnapshot()` / `mergeSnapshot()` are the sync entry points. `SettingsState` holds WebDAV config in `SharedPreferences`.
- `lib/services/` — `StorageService` (persistence), `scoring.dart` (scoring engine), `default_template.dart` (seed template), `attachment_service.dart`, `merge_service.dart` (record-level merge engine — pure, unit-tested), `backup_service.dart` (WebDAV; `fetchSnapshot`/`downloadAttachments` feed merge), `lan_sync_service.dart` (private LAN HTTP protocol), `import_export_service.dart`.
- `lib/pages/` + `lib/widgets/` — UI. `HomePage` is a 3-tab `NavigationBar` (记录 / 归档 / 设置). The records and archive pages share `widgets/year_section.dart` (the archive page passes `readOnly: true`). Sync UI: `webdav_settings_page.dart` (恢复 offers merge/overwrite), `lan_sync_page.dart` (QR host + scan/manual connect).

### Scoring model (the core domain logic — `lib/services/scoring.dart`)
A record's score is resolved by matching it against the template's `ScoreRule` list: a rule applies if every non-null field (categoryId, awarded, awardLevel, rank, role) equals the record's, and the **most specific** matching rule wins (`ScoreRule.specificity`). Key rules:
- Uncategorized records always score 0.
- Per-record display is `cumulative(delta)/cap`, e.g. `8(+3)/25` — `delta` is this record's own score, `cumulative` is the running category total up to and including it, `cap` is the category's `yearCap`. Built by `categoryCumulativeUpTo` (needs records in **ascending** time order — use `AppState.recordsOfYearAsc`).
- A year's total (`yearTotal`) sums each category's points **capped at that category's `yearCap`**, plus uncategorized points uncapped. The year total may legitimately exceed the year cap `Template.yearScoreCap` (= sum of category caps; shown in red when it does). The records page only lets you name a year — the cap is configured in the template editor.

### Sync & merge (`lib/services/merge_service.dart`)
Both sync paths converge on `MergeService.merge(local, remote)` — a pure function over `SyncSnapshot` (template + years + records + tombstones). Rules: entities align by `id`, **newest `updatedAt` wins** (no per-conflict prompts); a tombstone with `deletedAt >= entity.updatedAt` suppresses re-adding a deleted entity (a later edit resurrects it); deleting a year also tombstones its records, and merge drops records orphaned from any surviving year; the template merges whole as last-writer-wins; tombstones older than `tombstoneTtl` (180d) are pruned. The result also reports `neededAttachments` (storedNames the merged set references) so transports can fetch missing binaries. Merge correctness is covered by `test/merge_test.dart` — keep it green when touching the engine.
- **WebDAV** (`backup_service.dart`): 恢复 offers 合并/覆盖. Merge reads remote `template.json`/`data.json` into memory (never overwriting local first), runs `mergeSnapshot`, downloads only missing attachments, then re-uploads so the cloud also becomes the union. Overwrite is the original whole-replace `restore`.
- **LAN** (`lan_sync_service.dart`): host opens an ephemeral `dart:io` `HttpServer`, shows a QR (`{host,port,token}` payload) + 6-digit pairing code; client scans (`mobile_scanner`, mobile-only) or enters manually, then **pull → merge → push** so both ends end up with the union in one session. Payload is a zip of `snapshot.json` + `attachments/*`. Token goes in the `x-sync-token` header. Native-only (web can't host); Windows triggers a firewall prompt on first listen.

### Storage (`lib/services/storage_service.dart`)
Branches on `kIsWeb`: native writes `template.json` / `data.json` (+ an `attachments/` dir) under the app documents directory; web stores the same JSON strings in `SharedPreferences`. When adding persisted data, route reads/writes through `_read`/`_write` so both platforms keep working. `data.json` holds `years` + `records` + `deletedYears`/`deletedRecords` tombstones (returned as a `DataBundle`). Full-data import/export (`AppState.exportAll`/`importAll`) bundles template + years + records + tombstones into one JSON file.

## Conventions / gotchas
- **file_picker is v11**: methods are static (`FilePicker.pickFiles(...)`, `FilePicker.saveFile(...)`), NOT `FilePicker.platform.*`.
- Category colors are stored as ARGB `int` and rendered via `Color(c.color)`. The palette for new categories lives in `lib/pages/template/category_editor.dart` (`kCategoryPalette`).
- Visual style follows a Figma reference: white year-header cards, pastel category-colored record cards, score format `X(+Y)/Z`. Theme is defined in `lib/theme/app_theme.dart`; match these tokens when adding UI.
- UI strings and code comments are in Chinese — keep that consistent.
- **`mobile_scanner` is mobile-only** (android/ios/macos/web — no Windows/Linux). Gate any scanner UI behind `!kIsWeb && (Platform.isAndroid || Platform.isIOS)` (see `lan_sync_page.dart`); desktop falls back to manual pairing. LAN sync needs Android `INTERNET`+`CAMERA` and iOS `NSCameraUsageDescription`+`NSLocalNetworkUsageDescription` (already declared).
