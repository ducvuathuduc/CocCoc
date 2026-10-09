# AI / speech evidence (checked 2026-10-03, Asia/Saigon)

Historical snapshot retained. [Current evidence](../audit/RESEARCH_EVIDENCE.md) and [provider benchmark](../ai/PROVIDER_BENCHMARK.md) supersede changing model/eligibility/price claims; old IDs/quotas are not operational defaults or current account guarantees.

Scope: official vendor documentation only. Cost classes use `FREE_FOREVER`, `FREE_TIER`, `STUDENT_BENEFIT`, `PROMOTIONAL_CREDIT`, `TRIAL`, or `PAID_ONLY`; “free” is never treated as unlimited. Scores are engineering judgments for this Flutter Android/iOS + TypeScript/Appwrite university demo, not benchmarks. No architecture choice is final until synthesis.

| Claim | Verdict | Exact field/default | Source | Checked on |
|---|---|---|---|---|
| Gemini Live is bidirectional audio and native-audio output; client apps need ephemeral tokens. | CONFIRMED | `AUDIO response modality`; `ephemeral tokens`; audio-only session limit `15 minutes`; native-audio context `128k tokens` | [Gemini Live capabilities](https://ai.google.dev/gemini-api/docs/live-api/capabilities#limitations) | 2026-10-03 |
| Gemini API has a documented free tier for current Live/transcribe models. | CONFIRMED | `Free Tier` = `Free of charge`; `gemini-3.5-transcribe-live` paid input `$3.50`/1M audio tokens, output `$21.00`/1M text tokens; effective blended `~$0.009 per min`; `gemini-3.5-transcribe` `~$0.005 per min` | [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) | 2026-10-03 |
| Google Cloud Speech-to-Text is composable STT, not a pronunciation scorer. | CONFIRMED | `0 minute to 60 minute` = `$0.00 (Free)` per month/account for listed standard recognition; `60 minute and above` = `$0.016 / 1 minute` (one listed standard SKU) | [Cloud STT pricing](https://cloud.google.com/speech-to-text/pricing) | 2026-10-03 |
| Google Cloud TTS is composable synthesis with a monthly free allowance and billing requirement. | CONFIRMED | first `1 million characters` WaveNet or `4 million characters` Standard free monthly; `must enable billing`; new customers get `$300` free credits | [Cloud TTS product/pricing](https://cloud.google.com/text-to-speech#pricing), [TTS pricing](https://cloud.google.com/text-to-speech/pricing) | 2026-10-03 |
| OpenAI Realtime supports speech-to-speech, WebRTC/WebSocket, and secure ephemeral mobile/browser credentials. | CONFIRMED | `POST /v1/realtime/client_secrets`; `/v1/realtime/calls`; model example `gpt-realtime-2.1`; connection `WebRTC` or `WebSocket`; client key `ek_...(ephemeral key from your server)` | [OpenAI Realtime guide](https://developers.openai.com/api/docs/guides/realtime) | 2026-10-03 |
| OpenAI Realtime is paid API usage; current documented prices are token based. | CONFIRMED | `gpt-realtime-2.1` Audio input `$32.00`/1M, output `$64.00`/1M; `gpt-realtime-2.1-mini` Audio input `$10.00`/1M, output `$20.00`/1M | [OpenAI pricing](https://platform.openai.com/pricing) | 2026-10-03 |
| Azure Speech Pronunciation Assessment is a dedicated assessment feature layered on STT. | CONFIRMED | `Accuracy`, `Fluency`, `Completeness`, `Miscue` included in baseline; `Prosody` is not; uses a `specific version of the speech to text model, different from the standard speech to text model`; uninterrupted streaming supported | [Azure pronunciation assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment) | 2026-10-03 |
| Azure pronunciation assessment has no evidence here of a forever-free product tier. | UNDOCUMENTED | pricing says same as STT for `Standard or commitment tier`; exact student/demo quota not verified | [Azure pronunciation assessment pricing section](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment#availability-and-pricing) | 2026-10-03 |
| Deepgram provides streaming STT/TTS over WebSockets and a client-side authentication mechanism, but exact free quota was not verified. | CONFIRMED / UNDOCUMENTED | documented endpoints `/listen` and `/speak`; `Sec-WebSocket-Protocol: token, YOUR_DEEPGRAM_API_KEY`; Deepgram docs found no verified free quota in this review | [Deepgram WebSocket auth](https://developers.deepgram.com/docs/using-the-sec-websocket-protocol), [Live streaming](https://developers.deepgram.com/docs/live-streaming-audio), [TTS streaming](https://developers.deepgram.com/docs/tts-streaming-feature-overview) | 2026-10-03 |
| Groq offers OpenAI-compatible STT endpoints and documented file size limits, but not pronunciation scoring. | CONFIRMED / UNDOCUMENTED | `POST https://api.groq.com/openai/v1/audio/transcriptions`; free-tier request limit `25MB`; dev-tier `100MB`; pricing/quota amount not verified here | [Groq STT docs](https://console.groq.com/docs/speech-to-text) | 2026-10-03 |
| Cloudflare Workers AI provides hosted Whisper STT and a bounded no-charge daily allocation. | CONFIRMED | model `@cf/openai/whisper`; unit price `$0.000453 per audio minute`; `10,000 Neurons per day` free; overage requires `Workers Paid`; reset `00:00 UTC` | [Cloudflare Whisper](https://developers.cloudflare.com/workers-ai/models/whisper/), [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/) | 2026-10-03 |
| whisper.cpp is an open-source/on-device STT portability option for both mobile platforms. | CONFIRMED (source code/repository) | supported platforms include `iOS` and `Android`; model is OpenAI Whisper ASR; repository lists C/C++ API and bindings | [ggml-org whisper.cpp repository](https://github.com/ggml-org/whisper.cpp) | 2026-10-03 |
| On-device pronunciation assessment equivalent to Azure’s phoneme/fluency/prosody scoring is available in the cited whisper.cpp source. | UNDOCUMENTED | no `Accuracy`, `Fluency`, `Completeness`, `Miscue`, or `Prosody` scorer documented in the cited repository | [ggml-org whisper.cpp repository](https://github.com/ggml-org/whisper.cpp) | 2026-10-03 |

## Capability and decision scores

Judgment scale 1–10: higher is better for that row’s criterion; scores are design judgments, not measured latency or accuracy.

| Candidate | Native live conversation | Separate STT/TTS pipeline | Pronunciation scoring | Flutter mobile fit | Demo cost fit | Portability/fallback | Cost class |
|---|---:|---:|---:|---:|---:|---:|---|
| Gemini Live / native audio | 9 | 6 | 2 | 6 | 8 | 5 | `FREE_TIER` then paid |
| Google Cloud STT + TTS | 3 | 9 | 2 | 8 | 7 | 6 | `FREE_TIER` (billing enabled) + `PROMOTIONAL_CREDIT` |
| OpenAI Realtime | 9 | 5 | 2 | 7 | 2 | 6 | `PAID_ONLY` |
| Azure Speech Pronunciation Assessment | 4 | 8 | 10 | 7 | 4 | 5 | `PAID_ONLY` / free status `UNVERIFIED` |
| Deepgram STT/TTS | 6 | 9 | 2 | 7 | 4 | 7 | free status `UNVERIFIED` |
| Groq Whisper + separate TTS | 2 | 7 | 2 | 7 | 5 | 7 | free status/quota `UNVERIFIED` |
| Cloudflare Workers AI Whisper | 2 | 7 | 2 | 8 | 8 | 8 | `FREE_TIER` (10,000 Neurons/day) |
| whisper.cpp on-device | 1 | 5 (STT only) | 1 | 5 | 10 | 10 | `FREE_FOREVER` software; device compute/storage cost |

## Architecture implications

* For a direct live agent, the documented safe pattern is Flutter client → TypeScript/Appwrite function creates short-lived provider credential → client connects directly over WebRTC/WebSocket. OpenAI explicitly documents this flow; Gemini explicitly requires ephemeral tokens for client-to-server use. Never ship a long-lived provider key in the app.
* For grading pronunciation, use a composable pipeline: record/stream audio → Azure Pronunciation Assessment → store score payload in Appwrite → optionally use Gemini/OpenAI/other model for feedback text. Generic STT, native audio, and TTS do not constitute pronunciation scoring.
* Keep an adapter boundary around `LiveSession`, `Transcriber`, `Synthesizer`, and `PronunciationAssessor`; this permits Gemini/OpenAI live fallback, Cloudflare/Groq/Deepgram STT fallback, and local whisper.cpp when offline.
* Cloudflare’s free amount is a daily compute allocation, not a promise of unlimited free speech. Google Cloud’s free STT/TTS amounts require billing and are monthly allowances. Google’s `$300` and similar credits are promotional credits, not free forever.
* Appwrite should issue provider credentials and persist only consented transcripts/scores. Provider WebRTC/WebSocket audio can bypass Appwrite after token issuance; this reduces backend audio relay cost and latency, but requires provider-specific client SDK/native bridge validation in Flutter.

## Recommended candidates (provisional)

* Primary live demo candidate: Gemini Live/native audio (`FREE_TIER` documented; strong low-latency interaction), with strict session/time/quota monitoring.
* Primary grading candidate: Azure Pronunciation Assessment (only cited service with explicit multi-level pronunciation scores); verify Vietnam region, supported English locale, and current billing/free eligibility before commitment.
* Composable fallback: Google Cloud STT + TTS (`FREE_TIER` monthly allowances, billing enabled) or Cloudflare Whisper for low-cost transcription; neither replaces pronunciation assessment.
* Offline fallback: whisper.cpp for transcription only. Treat pronunciation scoring as unavailable offline until a separate, validated model is selected.
* OpenAI Realtime is technically attractive for direct live voice but currently scores poorly on a near-zero VND demo because the cited pricing is paid-only.

## Unresolved facts to verify before architecture lock

1. Provider account eligibility, card requirement, and actual quota for the team’s countries/accounts (Gemini, Azure, Deepgram, Groq, OpenAI, Cloudflare) are account/plan dependent and were not inferred.
2. Current Flutter plugins/native bridges for Gemini Live, OpenAI Realtime WebRTC, Azure Speech SDK, and whisper.cpp iOS/Android must be tested on target devices; official web docs do not prove Flutter support.
3. Vietnam data residency, retention, DPA/education policy, and Appwrite deployment region were not researched in this evidence pass.
4. No source reviewed provides a defensible cross-vendor latency or pronunciation accuracy comparison; do not publish numerical latency/accuracy claims.

## Targeted follow-up evidence (checked 2026-10-03)

### Gemini model freeze candidates

* **Free text tutoring model:** `gemini-2.5-flash-lite` is listed as Stable, with `Live API Not supported`, input token limit `1,048,576`, output token limit `65,536`, and pricing table `Free Tier: Free of charge`. This is the defensible free text tutor candidate, subject to the account's current rate limits: [model page](https://ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-lite), [pricing](https://ai.google.dev/gemini-api/docs/pricing).
* **Free Live native-audio model:** pricing explicitly lists `gemini-2.5-flash-native-audio-preview-12-2025` under “Gemini 2.5 Flash Native Audio (Live API)” with `Free Tier: Free of charge` for input and output. The models page labels the same endpoint the Live native-audio model. It is a **preview**, so status and limits must be rechecked before a public demo: [pricing](https://ai.google.dev/gemini-api/docs/pricing), [models](https://ai.google.dev/gemini-api/docs/models).
* Live audio transport is exact: input `raw, little-endian, 16-bit PCM, 16kHz`; output `24kHz`; the API can resample another input rate, but client resampling to 16kHz is recommended: [Live capabilities](https://ai.google.dev/gemini-api/docs/live-api/capabilities).
* Gemini ephemeral token fields and defaults are documented: `expireTime` defaults to `30 minutes in the future` and must be `<20 hours` in the future; `newSessionExpireTime` defaults to `60 seconds in the future` and must be `<20 hours`; `uses` defaults to `1`, while `0` means no limit; `sessionResumption` does not count as a use. Tokens are `only compatible with Live API` and currently use `v1beta`: [API reference](https://ai.google.dev/api/live), [ephemeral-token guide](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens).
* Ephemeral tokens can constrain the Live setup using `bidiGenerateContentSetup` / `liveConnectConstraints`, including `model`, `config`, `sessionResumption`, and `responseModalities: ["AUDIO"]`; this is useful for preventing a client from changing the server-selected model/config. The docs’ example currently shows `gemini-3.8-live`, so do not copy that example as the default model without checking availability: [ephemeral-token guide](https://ai.google.dev/gemini-api/docs/live-api/ephemeral-tokens).

### Azure F0 and pronunciation assessment

* Azure’s official pricing page documents **Free (F0)** `Real-time Transcription: 5 audio hours free per month` for Standard/Custom STT and `Neural: 0.5 million characters free per month` for TTS. The 5 hours are shared between Standard and Custom; Batch is not supported: [Azure Speech pricing](https://azure.microsoft.com/en-us/pricing/details/speech/).
* Pronunciation Assessment is charged as standard Speech to Text, and the pricing page lists `Pronunciation Assessment (prosody)` as an enhanced add-on. However, the docs do **not** explicitly state that the assessment feature (especially prosody) is available under F0. Verdict: **baseline assessment on F0 UNVERIFIED**; budget it as paid until an actual F0 subscription/region test confirms it. [Azure pronunciation docs](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment), [pricing](https://azure.microsoft.com/en-us/pricing/details/speech/).
* Azure’s cited docs describe full-text `Accuracy`, `Fluency`, `Completeness`, `Prosody`, and word-level `Miscue`; they do not establish an `en-US`-specific stress/phoneme quality guarantee. Treat stress-level claims as **UNVERIFIED** and validate with the target locale and scripted text: [pronunciation assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment).

### Groq, Deepgram, and Cloudflare quota/cost distinctions

* Groq’s published base limits for `whisper-large-v3-turbo` are `RPM 20`, `RPD 2K`, `ASH 7.2K`, `ASD 28.8K`; the model page lists `$0.04` per hour and max file size `100 MB`. The STT guide separately says `25 MB (free tier), 100MB (dev tier)` for file uploads. These are rate limits, not a “free forever” grant; classify Groq as `FREE_TIER` only for the documented free-plan access, with exact account limits subject to the Limits page: [Groq rate limits](https://console.groq.com/docs/rate-limits), [Whisper model](https://console.groq.com/docs/model/whisper-large-v3-turbo), [STT guide](https://console.groq.com/docs/speech-to-text).
* Deepgram’s official pricing says every new account receives `$200 in free credit`, `No credit card required`, `No expiration`, and that usage does not automatically switch to pay-as-you-go when credit is exhausted. This is best classified `PROMOTIONAL_CREDIT` (account credit), not `FREE_FOREVER`; it is not a verified monthly free tier: [Deepgram pricing](https://deepgram.com/pricing), [first request](https://developers.deepgram.com/guides/fundamentals/make-your-first-api-request).
* Cloudflare separates Workers platform limits from Workers AI Neurons: Workers Free has `100,000/day` requests and `10 ms` CPU time per HTTP request, while Workers AI separately grants `10,000 Neurons per day` and charges `$0.011 / 1,000 Neurons` above that on Workers Paid. Network wait time does not count toward Worker CPU time. Therefore a token-issuing proxy can hit the request/CPU limits independently of AI inference Neurons: [Workers limits](https://developers.cloudflare.com/workers/platform/limits/), [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/).
