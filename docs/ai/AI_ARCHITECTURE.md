# AI, listening and speech architecture

Current facts/model status/prices are in [provider benchmark](PROVIDER_BENCHMARK.md) and [current research](../audit/RESEARCH_EVIDENCE.md); historical [AI evidence](../research/AI_EVIDENCE.md) retains its date; cost controls in [COST_MODEL](../devops/COST_MODEL.md). This document defines implementation decisions. No provider latency/accuracy benchmark has been run.

## Decisions and model routing

Text primary candidate: gemini-3.5-flash-lite, authored correction first. Native Live candidate: gemini-3.8-live, disabled until account/v1beta credential/native-device probes. Existing eligible 2.5 text remains fallback; legacy native-audio preview has earliest retirement 2026-11-17. Token guide examples name other models: never substitute an example model without checking availability/pricing. IDs are allowlisted configuration, not embedded Flutter UI logic.

Fallback A: turn-based Groq whisper-large-v3-turbo STT → Gemini text → installed device TTS or bundled reply audio. Fallback B: Cloudflare @cf/openai/whisper STT under Neurons allowance → authored scenario response/bundled audio; no additional Worker gateway needed, server calls configured API. Deepgram is an optional credit-backed streaming alternative; not part of baseline. OpenAI gpt-realtime/gpt-realtime-mini are paid candidates only with separately authorized API funds, disabled by default; current GA credential contract must be verified rather than inherited from beta docs. Google Cloud STT/TTS monthly billing-enabled quotas are compared but unnecessary defaults. Dedicated pronunciation uses Azure assessment behind an actual entitlement test; F0 assessment availability remains UNVERIFIED, enhanced prosody disabled unless confirmed allocation.

Offline guaranteed mode: reference audio + record/replay shadowing + typed answer; no numerical pronunciation score. OS dictation/TTS only if installed/available; whisper.cpp is a later ADR candidate because model downloads/native integration add device cost. No Python service needed.

## Capability comparison and admission

[Provider benchmark](PROVIDER_BENCHMARK.md) owns primary/fallback choices, protocol, model IDs, pricing and pending measurements. Previous 1–10 subjective rankings were removed: they were not empirical quality/latency/concurrency evidence. Native speech-to-speech is the gated conversation mode; batch STT/text/TTS plus a separate dedicated assessor is the recorded/graded mode. Both remain within AI ownership. Neither transcript similarity nor conversational fluency proves phoneme accuracy. Vietnamese learner accents require an actual English reference dataset; vi-VN assessment availability does not imply Vietnamese prosody.
## Adapter contracts

Backend TextTutor.generate(reference, learnerText, level, locale, requestId)→validated TutorResult. Transcriber.transcribe(wav, locale)→final transcript/confidence|null. PronunciationAssessor.assess(wav, reference, locale)→Assessment with nullable metrics and scoreState. Synthesizer.selectAssetOrGenerate(text,voice,speed,locale)→versioned audio asset or device directive. LiveIssuer.issue(userId,scenarioId,reservation)→single-use constrained VoiceLease.

Flutter SpeechSessionController owns lifecycle; SpeechTransport exposes connect/sendPcm/endTurn/cancelPlayback/close and normalized events. Gemini-specific setup/audio JSON lives in one adapter under features/speaking/data; transport details never enter views. Azure/Groq/Cloudflare adapters are server-side. Shared wire types derive from OpenAPI, no manual rival schema.

## Secure Live reservation and credentials

Use POST Gemini v1beta/auth_tokens via server credential, with uses=1; newSessionExpireTime=issuedAt+60s; request expireTime=issuedAt+180s as a project lease policy, not a documented provider maximum. Pin model and liveConnectConstraints to AUDIO modality, allowed system/scenario instructions and audio/transcription configuration, without arbitrary tools/config. [Official ephemeral-token guide](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens) documents a 30-minute default and refers field constraints to the API reference; P8 must prove the shorter requested bound on an active socket before enablement. Lock all security-sensitive configuration using current SDK/reference fields. No automatic context compression or post-expiry resumption.

Appwrite transaction reserves180s and claims deterministic a_active_slots(userId) before mint; daily rule used+reserved+180≤600 seconds and at most2native grants/day are project policies independent of vendor quotas. On successful mint, charge the entire reservation as consumed. Client close/heartbeat cannot refund budget or prove vendor usage. If mint outcome is ambiguous, consume budget conservatively. A lost token delivery returns VOICE_TOKEN_DELIVERY_UNCERTAIN until original lease expiry; do not issue a replacement token under the same reservation. Reconnect uses the same credential/provider-supported resumption only within original expiry and only if P8 proves one-session constraints. Otherwise switch to TURN.

Server/provider enforcement and reservation accounting are distinct. Appwrite cannot close a direct socket. If provider expiry/config restrictions fail device/security probes, **nativeLive=false** and use TURN until a server-controlled relay has a justified hosting ADR. UI timer≤180s is usability, not security. Key is a no-billing/free allocation by default; provider quotas and hard spend control contain residual usage. Tokens, resumption handles and raw audio never logged. Only allowlisted model configuration can mint a grant.

## Lifecycle and audio contract

~~~mermaid
stateDiagram-v2
  [*] --> Initializing
  Initializing --> Permission
  Permission --> Ready: granted + capability
  Permission --> Shadowing: denied/unavailable
  Ready --> Connecting
  Connecting --> Listening: setup acknowledged
  Connecting --> TurnMode: timeout/quota
  Listening --> Finalizing: endTurn/VAD
  Finalizing --> Responding: tutor audio/text
  Finalizing --> TurnMode: final timeout
  Responding --> Listening: playback complete
  Responding --> Interrupting: barge-in
  Interrupting --> Listening: cancel old turn/audio
  Listening --> Paused: background/focus loss
  Responding --> Paused: background/focus loss
  Paused --> Ready: explicit resume
  TurnMode --> Listening: record next bounded turn
  Listening --> Closed: close/expiry
  Responding --> Closed: close/expiry
  Closed --> [*]
~~~

1 Initialize manifest/scenario and capability; 2 obtain mic permission then reserve lease; 3 configure audio session; 4 capture mono little-endian PCM16 at16kHz; 5 aggregate20ms/640-byte frames into100ms transport chunks; 6 local energy VAD detects voiced≥300ms and end silence600ms; 7 send bounded base64 WSS audio; 8 partial transcription optional; 9 finalize after end marker≤3s; 10 assessment runs separately when selected; 11 reference-bound feedback; 12 next tutor turn; 13 native24kHz PCM or turn device/bundled TTS; 14 playback via native PCM queue; 15 interruption; 16 one bounded reconnect/fallback; 17 close/expire/release audio resources.

Local VAD is a heuristic, not speech/noise classifier: adaptive noise floor from500ms pre-roll, voiced when RMS>max(-45dBFS,noiseFloor+10dB), sustained300ms. Thresholds are tunable after device recordings, never clinical/accuracy claims. Noise/silence leads retry without a score.

Output PCM24kHz goes to a small Kotlin AudioTrack / iOS AVAudioEngine bridge with bounded ring buffer≤500ms; just_audio handles compressed cached assets and is not assumed to stream raw PCM directly. This native bridge is limited to audio I/O, not separate business logic. Echo cancellation/audio routing evaluated on speaker/headset; recording and playback simultaneous only after successful device test. Safe initial barge-in uses a visible interrupt button; automatic VAD interruption gated on echo tests.

Normalized events include sessionId, epoch, turnId, local seq, kind ready/partial/final/audio/turnComplete/interrupted/error/closed. Gemini payloads may not supply these sequence fields: adapter assigns local seq in arrival order. Discard old epoch/turn audio. ServerInterrupted clears playback queue immediately. Input queue≤1s; overflow stops capture and reports slow network instead of unbounded buffering. Background/call/focus change stops microphone; resume new epoch, no audio replay. Bluetooth route change recreates capture and resampling. Audio focus/lifecycle tests are release gates.

Distinguish wire lease epoch from local transport epoch: HTTP heartbeat/turn fields echo server-issued VoiceLease.epoch; local adapter increments its own transportEpoch on reconnect/route change and stamps normalized events so stale callbacks are discarded. It never invents a new server epoch. Closing/expiry may invalidate the lease by server epoch increment; VOICE_EPOCH_CONFLICT requires reading current state/new session, not changing the server from a client header. A background LIVE session follows the bounded resumption/expiry policy; a new TURN session obtains its own lease epoch.

## Listening and assessment

Listen assets generated/recorded at author time; normal/slow cached by text hash+locale+voice+speed+provider+modelVersion+format. Pregenerate only changed keys; device TTS last resort with clear label. No on-demand AI for repeat/slow ordinary exercise.

Assessment job POST WAV≤15s, server validates RIFF format/sample/duration/hash/reference, writes private file, queues Azure request (or STT-only fallback), polls typed result. scoreState VALID only if dedicated scorer+locale/referenceHash/modelVersion present and quality/confidence checks pass; otherwise NULL_UNAVAILABLE/NULL_LOW_CONFIDENCE/FAILED, every numeric metric null. Prosody/stress nullable and not synthesized by LLM. Mispronunciation labels and word/phoneme arrays come from scorer. No hallucinated “native accent percentage”.

Accepted jobs dispatch via a private asynchronous execution of the same AI Function (local adapter invokes its in-process worker), after durable job/quota transaction; scheduled sweep repairs queued work. P1 verifies the platform invocation adapter; no extra assessment service/function. The30s assessment target assumes immediate dispatch, while scheduler-only recovery may be slower and UI stays pending. A worker claims job/lease transactionally before provider call. Audio attempts reserve actual measured seconds; ambiguous/crashed dispatch is terminal rather than blindly repeated. Retry policy and token receipt exceptions are canonical in [EVENTS_ERRORS](../api/EVENTS_ERRORS.md#voice-and-job-retry-exceptions).

Check microphone permission and device capability before requesting a native lease. Expired/background sessions drop buffered audio. Client transport consumes server-selected lease data; capability output is availability, not permission to choose a provider/model or override configuration. A TURN session uses server HTTP commands and the same recorded-speech quota as assessment; no native slot/token.

Lesson speaking grade: trusted job must belong to subject and matching immutable exercise. With VALID scorer, correct iff accuracy≥70 and completeness≥80 (project threshold to calibrate); unscored STT mode grades only normalized authored transcript equality and labels feedback “words recognized, pronunciation not assessed”. If no trusted final transcript, use authored written substitute; not a guessed correct answer. Learning may query AI for this optional job via subject-verified request; ordinary lesson/completion never requires AI.

V1 quality gate: valid decoded≤15s WAV,≥300ms voiced input under the documented VAD, successful dedicated-engine recognition, nonempty transcript, matching locale/reference, finite required accuracy/completeness within0..100 and real scorer provenance. If provider returns a documented0..1recognition confidence, require≥0.5; absent confidence remains unknown rather than synthesized, with other gates still required. Silence/failed recognition/low returned confidence→NULL_LOW_CONFIDENCE with every numeric metric null and no fabricated word/miscue arrays. Failed job→FAILED; no scorer entitlement→NULL_UNAVAILABLE. These thresholds are project heuristics to calibrate in P8, not validated assessment accuracy claims.

QUEUED/RUNNING jobs use scoreState=NULL_UNAVAILABLE, unavailableReason=pending, all metrics null; UI selects the job status first and displays pending rather than scorer-disabled. On terminal response use actual failure/unavailability/valid state. Poll at1s,2s,3s then5s intervals for≤60s while visible; thereafter show pending/revisit action, never create a new job automatically. Background stops polling; returning reads the same jobId.

Raw recordings auto-delete≤24h; results≤7days; saving a session transcript for learning history is opt-in with delete control. Default no long-term conversational personal-memory extraction.
