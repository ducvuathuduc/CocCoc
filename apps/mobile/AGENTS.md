# Flutter module

Before changing code, read [DESIGN](../../docs/design/DESIGN.md), the relevant screen and SRS IDs, and [STACK](../../docs/architecture/STACK.md). Usage and runtime switches are in [README](README.md).

## Layout

```text
lib/main.dart                 app entry + router
lib/core/                     design system (core/design), API contracts (core/api, generated/ = DO NOT EDIT), shared widgets
lib/features/<feature>/       presentation/ (views) · application/ (ViewModels, Riverpod) · data/ (repositories, mock fixtures) · domain/ · services/ (SDK/HTTP/native I/O)
test/                         widget/golden/unit tests (~440); test/api_contracts_round_trip_test.dart pins DTOs to OpenAPI
assets/                       fonts, motion, reference art (see assets/PROVENANCE.md)
```

Views contain only widgets. ViewModels own local commands and state. Repositories own cache and retry. Services wrap SDK, HTTP and native I/O. Riverpod providers are written by hand; views never call vendor code directly. Use sealed exercise/answer types and treat results as server-authoritative. Local fake repositories must conform to OpenAPI. The native audio bridge is limited to Kotlin AudioTrack and iOS AVAudioEngine I/O.

**Known follow-up (not moved yet):** the profile, league, energy, Super/Max, streak and achievement screens live under `features/progress/presentation/`, but `features/profile/` holds only the profile tab and friends. The backend owner of all of these is Progress, so the code works. The folder names just do not match the screens. Moving them touches imports across about 440 tests, so it needs its own task with a full `pnpm verify`.

## Commands (from repository root unless noted)

```sh
pnpm verify                                   # format + analyze + all Flutter tests + blueprint
cd apps/mobile && flutter pub get --offline   # restore deps; revert any pubspec.lock mirror-URL rewrite
flutter analyze --no-pub
flutter test --no-pub --dart-define=ENABLE_MASCOT_MOTION=false
flutter test --no-pub test/api_contracts_round_trip_test.dart
python3 tools/palette_check.py                # (root) colors must come from docs/design/qa/palette_from_refs.json
pnpm contracts:dart                           # regenerate lib/core/api/generated after an OpenAPI change
```

## Gates

Before handing off, run analyze with no issues, all tests green, and the targeted tests of the feature you touched. A new color must pass `palette_check`, which already has a known baseline of unmatched legacy colors; never add to it. Test lifecycle and disposal, text scale 2 and semantics, denied permission, offline kill and resume, and the feature you were assigned. Never treat an emulator golden as physical speech QA. `pubspec.lock` is an exclusive change area.
