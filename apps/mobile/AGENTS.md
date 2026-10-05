# Flutter module

Read docs/design/DESIGN.md, relevant screen/SRS IDs and docs/architecture/STACK.md. Views contain widgets only; ViewModels own local commands/state; repositories own cache/retry; services wrap SDK/HTTP/native I/O. Manual Riverpod providers; no provider vendor code in views.

Use feature folders, sealed exercise/answer types, server-authoritative results and durable Drift journal. Local fake repositories conform to OpenAPI. Native audio bridge only Kotlin AudioTrack/iOS AVAudioEngine I/O. Test lifecycle/disposal, text-scale2/semantics, denied permission, offline kill/resume, and current assigned feature. Never treat an emulator golden as physical speech QA.
