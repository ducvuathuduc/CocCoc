# Provider decisions, pricing and benchmark admission

Accessed 2026-10-09. [Evidence IDs R10–R20](../audit/RESEARCH_EVIDENCE.md) own source provenance. All p50/p95, accent-quality, structured-output failure rate and native battery/frame measurements are **PENDING BENCHMARK**. Vendor latency statements are not our measurements. Vietnam availability, account/model entitlement and quota consoles must be checked before enablement. Paid fallbacks remain disabled.

| Capability | Primary decision / protocol | Fallback / change trigger | Proof required |
|---|---|---|---|
| Deterministic answer grading | authored key + server validator; REST | local provisional checker offline | no LLM; normalization and malicious answer fixtures |
| Text explanation | authored correction first; candidate gemini-3.5-flash-lite, server REST | eligible existing gemini-2.5-flash-lite or authored template; switch when entitlement/evals fail | strict JSON, ≤120 words, no changed answer key, quota/timeouts |
| Live conversation | candidate gemini-3.8-live; native client direct WebSocket after scoped lease | Groq batch STT → text → bundled/device TTS; typed/shadowing if quota exhausted | token/config expiry enforced, native PCM/cancel/focus, provider-account budget; Flutter integration unproven |
| Streaming transcript | candidate gemini-3.5-transcribe-live; WebSocket | turn transcript; Mistral realtime is optional separately admitted alternative | partial/final ordering, false starts, stale epoch/cancel |
| Batch transcript | Groq whisper-large-v3-turbo; server file REST | Cloudflare @cf/openai/whisper; current Gemini batch transcribe only after account admission | 15s clips, noise/Vietnamese-accent English WER, timeout/429 |
| Listening/TTS | immutable authored/bundled audio; no inference per replay | author-time gemini-3.8-flash-lite-tts profile or installed OS TTS | hash/locale/voice/speed cache; voice preview/controls; no fake offline OS availability |
| Pronunciation | Azure scripted assessment en-US English reference phrase | scores null + transcript/record-replay; no LLM numeric fallback | en-US needed for prosody; vi-VN assessment supports a subset of metrics, not established Vietnamese prosody/phoneme names; locale/confidence gates |
| Paid alternatives | OpenAI gpt-realtime(-mini), Mistral audio, MiniMax TTS; text-only DeepSeek | never auto-enable from an owned coding subscription | explicit API funds, region/access, bounded credentials, Flutter benchmark |

## Official list-price snapshot

Prices below are USD per listed unit, excluding taxes/overage. [Google pricing](https://ai.google.dev/gemini-api/docs/pricing.md) supports these Standard rows: gemini-3.5-flash-lite input $0.30/output $2.50 per million tokens; gemini-3.8-live audio input $0.005/min and output $0.018/min; gemini-3.5-transcribe-live audio input $0.005/min plus text output $0.004/min; gemini-3.5-transcribe batch audio input $0.003/min plus text output $0.002/min. These rows show free pricing but account quotas are not guaranteed. gemini-3.8-flash-lite-tts input $0.50/output $6 per million corresponding text/audio tokens through 2026-12-31; listed rates double from 2027-01-01. Do not infer minutes from tokens without actual usage.

[Groq](https://console.groq.com/docs/speech-to-text) lists turbo $0.04/audio hour and large-v3 $0.111/audio hour. [Workers AI](https://developers.cloudflare.com/workers-ai/platform/pricing/) uses model-specific Neurons and an included daily allowance; measure actual Neurons/request instead of promising audio minutes. Azure/Mistral/MiniMax/OpenAI effective demo cost remains ACCOUNT-DEPENDENT until a current account/region price and allowance are recorded. No provider was called for this report.

## Model migration and security

[Google retirement schedule](https://ai.google.dev/gemini-api/docs/deprecations/) gives 2026-11-17 as earliest shutdown for legacy native-audio preview; migrate config/evals before that boundary. 2.5 text is not deprecated, but new-project access is restricted. Current candidate profiles replace old defaults in design only; no live adapter is enabled. IDs remain server allowlists, never user-selectable input.

[Ephemeral credentials](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens) are Live/v1beta-only. Set single-use, locked model/config, a short start window and 180s server reservation. Verify whether expireTime/config actually bounds an extracted-token socket; reserve worst-case provider usage and block new grants. Appwrite cannot terminate a direct socket. If required budget bounds fail, keep Live disabled and open a justified relay ADR rather than pretending client timers secure it.

## Runnable benchmark procedure

`pnpm backend:smoke` proves only deterministic fake event delivery. [AI evaluations](AI_EVALS.md) define consented audio cases and gates. `node tools/evals/voice-harness.mjs` validates a sample metadata fixture without calling a provider; `node tools/evals/voice-harness.mjs --report <results.json>` aggregates explicitly supplied measured samples. Required sample fields: capability/provider/model/locale/device/network, startMs/endMs, outcome, expected transcript, actual transcript, assessed metrics or null, cancellation and quota disposition. At least 30 admitted samples per device/network/capability; report failures and confidence, not only successful latency.
