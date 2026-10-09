# Frozen stack and package research

Resolved supplement 2026-10-09–10: mobile lock preserved; root pnpm-lock.yaml pins TypeScript5.9.3, node-appwrite29.2.0, ESLint10.12.0/typescript-eslint8.71.1, Prettier3.9.9, AJV8.20.0, Redocly2.62.1 and openapi-typescript7.13.0. [Compatibility receipt](../audit/VALIDATION.md): latest TS7 was incompatible with generator/parser. Backend16 tests/smoke/audit also passed under verified portable Node22.23.3; CI pins that version. Drift/http/DTO generation below remain planned mobile integrations; Cloud runtime is still an account gate.

Research snapshot2026-10-03; final validation2026-10-04. Version numbers below came from **pub.dev package API** and npm registry, not memory. Local command confirmed Flutter3.47.0/Dart3.13.0, Node24.16.0, Codex0.153.4. Latest Flutter patch is not established from official rendered archive; pin known stable3.47.0 until approved update. Backend runtime baseline Node22; installed Node24 is not assumed to match Cloud Functions.

Flutter architecture: feature-first MVVM + manual Riverpod Notifier/AsyncNotifier + typed repositories; go_router; SDK for Account, http for business REST; Drift SQLite for durable journal. Use json_serializable for DTOs and Drift code generation, with one build_runner command; no Freezed or Riverpod generation. Domain model validation stays explicit.

Backend: TypeScript, Node22, pnpm workspace, node-appwrite29.0.0 observed current npm stable; thin Appwrite-context and local Node HTTP adapters; built-in fetch/crypto; schema validation generated/derived from OpenAPI at build time; Vitest/ESLint/Prettier pinned in P1. No NestJS/Fastify required for three small Function routers. OpenAPI3.1 owns wire format, not a shared Dart/TypeScript domain-model package.

Contract tooling observed2026-10-04: openapi-typescript7.13.0 derives TS wire types; AJV8.20.0 + ajv-formats3.0.1 validate JSONSchema2020-12 bodies/fixtures; Redocly CLI2.57.0 lints OpenAPI. Dart DTO declarations map the frozen schema and use json_serializable for serializers, with positive/negative round-trip fixtures checked against the same schema. Do not generate a second networking SDK or add Dio solely for generator convenience. Drift and DTO serializers share build_runner; no bespoke full Dart code generator.

Installed Gitleaks8.30.1 and staged command were verified locally. Repository hooks require Git-root verification and reject scanner error output even with status0; P1 pins the verified release before CI/commit use. Official implementation: [Gitleaks](https://github.com/gitleaks/gitleaks), [staged command source](https://github.com/gitleaks/gitleaks/blob/master/cmd/git.go). Phase0 has no initialized Git repository and performs no commit.

## Registry observations and inclusion

All are observed latest stable versions on the research date, **not an installed compatible lockfile**. Link labels resolve to primary package pages; machine source is https://pub.dev/api/packages/PACKAGE and /score. Platforms below are Android/iOS suitability from package metadata/docs where applicable, not tested native behavior.

| Package / version | Published | Inclusion / adoption evidence / platform | Alternative / size or health consideration |
|---|---|---|---|
| [flutter_riverpod3.4.3](https://pub.dev/packages/flutter_riverpod) | 2026-09-03 | selected; Dart^3.12; 3.42M downloads/30d snapshot; pure Flutter | BLoC9.1.1 rejected for event/state ceremony; manual providers |
| [flutter_bloc9.1.1](https://pub.dev/packages/flutter_bloc) | 2025-05-02 | compared, not installed; 2.06M/30d | older publication does not alone mean unhealthy |
| [provider6.1.5+1](https://pub.dev/packages/provider) | 2025-08-19 | compared, not installed; 1.15M/30d | lighter simple CRUD; weaker async lifecycle conventions for this app |
| [go_router18.0.2](https://pub.dev/packages/go_router) | 2026-09-28 | selected; Flutter maintained; Dart^3.12; 4.48M/30d | manual Navigator rejected for deep-link/guard upkeep |
| [appwrite27.0.0](https://pub.dev/packages/appwrite) | 2026-09-24 | selected auth/client platform; 15.6K/30d | SDK Cloud/API compatibility proved P1, no generic DB client writes |
| [http1.6.0](https://pub.dev/packages/http) | 2025-11-10 | selected REST; 12.5M/30d | Dio5.11.1 compared; add only if measured I/O need |
| [dio5.11.1](https://pub.dev/packages/dio) | 2026-09-04 | not installed; 4.72M/30d | avoid two parallel retry/interceptor systems |
| [json_serializable6.14.1](https://pub.dev/packages/json_serializable), [json_annotation4.12.0](https://pub.dev/packages/json_annotation) | 2026-07-30 /05-15 | selected dev/runtime DTO generation | build_runner2.16.1 observed09-02; generated diff gate |
| [drift2.35.1](https://pub.dev/packages/drift), [drift_dev2.35.1](https://pub.dev/packages/drift_dev) | 2026-09-30 | selected journal/cache; 1.42M drift/30d | schema migration/native SQLite footprint benchmark in P1/P10 |
| [drift_flutter0.3.1](https://pub.dev/packages/drift_flutter) | 2026-07-11 | selected Flutter SQLite integration | no second embedded database |
| [isar3.1.0+1](https://pub.dev/packages/isar) | 2023-04-25 | original compared/rejected; advertised SDK<3 in fetched metadata | do not equate with community forks; original incompatible with baseline |
| [hive_ce2.20.1](https://pub.dev/packages/hive_ce) | 2026-09-27 | compared current successor; 1.18M/30d | good key-value cache; SQLite fits journal/query constraints |
| [shared_preferences2.5.5](https://pub.dev/packages/shared_preferences) | 2026-03-25 | selected simple local settings, A/iOS | not transactional journal or token vault |
| [flutter_secure_storage11.2.0](https://pub.dev/packages/flutter_secure_storage) | 2026-09-16 | selected app-sensitive key storage A/iOS | platform keychain/keystore migration/device tests |
| [record7.1.1](https://pub.dev/packages/record) | 2026-06-29 | selected A/iOS capture/PCM streaming; Dart^3.12 | confirm actual PCM buffer/sample route; no fake raw-audio support |
| [just_audio0.10.6](https://pub.dev/packages/just_audio), [audio_session0.2.4](https://pub.dev/packages/audio_session) | 2026-06-29 | selected cached assets/audio focus A/iOS | arbitrary raw PCM playback not assumed; native ring-buffer bridge P8 |
| [permission_handler13.0.2](https://pub.dev/packages/permission_handler) | 2026-09-04 | selected mic and OS settings A/iOS | native manifest/Info.plist and permanent-denial tests |
| [web_socket_channel3.0.3](https://pub.dev/packages/web_socket_channel) | 2025-04-17 | selected Gemini native transport, pure Dart | WebRTC only for enabled paid alternative |
| [flutter_webrtc1.6.2+hotfix.3](https://pub.dev/packages/flutter_webrtc) | 2026-09-15 | compared, deferred; A/iOS | heavier native surface; unnecessary Gemini PCM WebSocket default |
| [flutter_tts4.2.5](https://pub.dev/packages/flutter_tts) | 2026-01-05 | P8 device TTS fallback A/iOS | voice installation/locale/offline support tested; bundled audio always available |
| [speech_to_text7.5.0](https://pub.dev/packages/speech_to_text) | 2026-09-14 | compared, deferred OS dictation option | OS speech may need internet; never pronunciation scoring |
| [flutter_local_notifications22.3.1](https://pub.dev/packages/flutter_local_notifications), [timezone0.11.1](https://pub.dev/packages/timezone) | 2026-09-13 /06-29 | P6/P9 local reminder A/iOS | OS delivery restrictions not guaranteed timing |
| [sentry_flutter9.30.1](https://pub.dev/packages/sentry_flutter) | 2026-09-22 | selected optional bounded crash capture | replay/profiling off; no sensitive payload |
| [uuid4.6.0](https://pub.dev/packages/uuid) | 2026-07-15 | selected operation/install IDs | cryptographically safe randomness; no device hardware IDs |
| [cryptography2.9.0](https://pub.dev/packages/cryptography) | 2025-11-21 | selected P4 SHA-256/Ed25519 bundle verification, pure Dart/platform implementation | published version from registry; shared canonical-byte/signature fixtures mandatory |
| [rive0.14.11](https://pub.dev/packages/rive), [lottie3.6.1](https://pub.dev/packages/lottie) | 2026-08-03 /09-18 | installed for authorized mock frontend | original vector assets; verified character inputs and reduced-motion/lifecycle behavior; full source timing/performance acceptance remains open |
| [qr_flutter4.1.0](https://pub.dev/documentation/qr_flutter/latest/qr_flutter/) | verified2026-10-05 | installed for native mock profile QR | encoded URL equals clipboard text; independent decode check; no sharing service or architecture change |
| [flutter_svg2.3.0](https://pub.dev/packages/flutter_svg) | verified2026-10-05 | pinned for local original avatar category SVGs | bundled assets; native Rive handles characters; no architecture change |
| [cupertino_icons1.0.9](https://pub.dev/packages/cupertino_icons/versions/1.0.9) | verified2026-10-05 | pinned icon font for existing Flutter Cupertino widgets | fixes missing-font web build warning; keeps current Cupertino API |
| [mocktail1.0.5](https://pub.dev/packages/mocktail) | 2026-04-10 | dev; prefer handwritten repository fakes, mock platform adapter as needed | no implementation-mirroring tests |
| [patrol4.10.0](https://pub.dev/packages/patrol) | 2026-09-15 | defer until native permission/device automation requires it | flutter_test/integration_test SDK first; pin golden host |
| [flutter_lints6.0.0](https://pub.dev/packages/flutter_lints) | 2025-05-27 | selected dev analyzer baseline | add only meaningful project rules |

Registry publish/score/download counts establish recent publication and rough adoption, **not issue health**. Open/critical issue counts, unresolved platform regressions and precise binary deltas are UNVERIFIED; P1 evaluates relevant pinned release issues and real Android/iOS build. No invented issue count or package size. Commit pubspec.lock and pnpm-lock.yaml; Flutter/Dart and runtime versions in infrastructure/toolchain.json. Upgrades are reviewed, never “latest” in CI.

## Windows evidence and workflow

flutter doctor -v on this machine confirmed Android SDK36.0.0, platform/build-tools36, licenses accepted, installed Android Studio JBR25.0.3. No Android physical device/emulator was attached. Visual Studio desktop C++ components are missing, which does not block Android/iOS targets. Do not install Windows desktop tooling for this mobile scope.

Install SDK at short path C:/flutter, put bin on PATH; Android Studio is SDK/emulator manager only. Terminal/Codex/Claude/VS Code are primary editors. Commands: flutter doctor -v; flutter doctor --android-licenses; flutter devices; flutter run -d deviceId; flutter analyze; flutter test; flutter build apk --release. P1 uses a verified Java17-compatible generated Flutter Gradle template/CI JDK17; local JBR25 is not silently forced across CI. Freeze actual AGP/Gradle/Kotlin versions generated by the pinned SDK, rather than independent speculative upgrades. API36 compile/target, min24 for Flutter3.47; confirm generated settings. iOS minimum15, Xcode/cloud image pinned after macOS build.
