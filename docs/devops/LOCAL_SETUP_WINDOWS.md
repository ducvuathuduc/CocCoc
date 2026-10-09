# How to reproduce the local foundation on Windows

From PowerShell at the repository root. Native Flutter Android development requires no local Mac/WSL/Docker/Kubernetes. Baseline Flutter 3.47.0/Dart 3.13.0 and mobile lock are retained. Backend checks passed under local Node24.16.0 and a verified portable Node22.23.3; backend CI pins22.23.3. Appwrite actual runtime remains a separate account probe. pnpm10.15.0 and compatible TypeScript5.9.3 are pinned; latest7.x failed generator/ESLint compatibility.

```powershell
flutter doctor -v
pnpm install --frozen-lockfile
Push-Location apps/mobile
flutter pub get --enforce-lockfile
Pop-Location
pnpm backend:verify
pnpm backend:smoke
pnpm contracts:check
pnpm api:lint
pnpm schema:plan
pnpm seed:check
pnpm audit:check
pnpm verify
```

`flutter doctor -v` currently reports some Android SDK licenses unaccepted. A developer must review/accept applicable SDK terms using `flutter doctor --android-licenses`; this refresh does not accept terms automatically. Windows desktop C++ toolchain warnings do not justify installing unrelated desktop components. No Android device is attached for this receipt.

Preview and builds use real existing root scripts:

```powershell
pnpm build:web
pnpm preview:web
# Open the loopback preview URL printed by the script.
pnpm build:android
# For a device, after flutter devices:
Push-Location apps/mobile
flutter run -d <actual-device-id> --dart-define=USE_MOCK_AUTH=true
Pop-Location
```

Fresh receipt: the default Android build failed on a modified immutable transform workspace in the global Gradle cache. The diagnostic build passed with a separate repo-local Gradle user home, keeping the old cache intact. To reproduce the tested build environment from the repository root, set `$env:GRADLE_USER_HOME = Join-Path (Get-Location) '.cache/gradle-android-refresh'` before `pnpm build:android`. The successful retry used the Flutter tools snapshot with `build apk --debug`; no mobile/Gradle/lock changes. A debug APK compile is not physical-device or release-signing proof. See [receipt](../audit/VALIDATION.md) and [artifact hashes](../audit/BUILD_ARTIFACTS.json).

Backend packages independently run a loopback health scaffold after `pnpm backend:build`:

```powershell
pnpm --filter @cocenglish/learning start
# In two separate terminals:
pnpm --filter @cocenglish/progress start
pnpm --filter @cocenglish/ai start
```

Health ports default 4301/4302/4303; `/ready` returns 401 and business routes 503 because cloud adapters are disabled. Local async demonstration is `pnpm backend:smoke`; it is not connected to mobile or a database. Per-service bundle command: `pnpm --filter @cocenglish/learning build` (substitute Progress/AI). Artifacts are self-contained `services/<owner>/dist/function.mjs`; shared transport is bundled, fixture stores excluded.

Human-readable install steps: install the pinned Flutter SDK at a short Windows path; install Android Studio/SDK36 and a compatible JDK through the Flutter-supported toolchain; place Flutter bin and Node22 on PATH; install pnpm10.15.0; restore locks with commands above. Verify actual Gradle/JDK compatibility by build rather than copying untested overrides. Do not upgrade the working SDK/lock to newest versions during setup.

iOS: use existing manual macOS CI job for simulator build. No Windows Xcode command is prescribed. Physical signing requires an eligible team/certificate/profile; TestFlight/store release is separately gated. [CI](CI_CD.md) and [release gate](../quality/RELEASE_GATE.md) distinguish those outputs.
