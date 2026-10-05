# AI evals and enablement gates

Normal CI uses deterministic fixtures/fake adapters. Live evals are manually triggered, quota-previewed, isolated from PR CI, and run only within existing authorized free/student allocation. Targets are in [NFR](../architecture/NFR.md); no empirical results yet.

| Eval | Dataset / assertion | Failure behavior |
|---|---|---|
| tutoring correctness | 60 authored A1/A2 vi→en cases including ambiguous accepted alternatives; model may explain, never change deterministic answer | any invented correctness/unsupported grammar correction rejects live enablement |
| structured response | 100 fixture valid/malformed/truncated/overlong/off-topic outputs | schema fail→authored template; no UI crash |
| pronunciation | 20reference phrases × clean/omitted word/noise/silence; bilingual human labels; measure scores and disagreements | metrics nullable when unavailable/low confidence; no claimed accuracy without dataset results |
| scorer separation | STT-only fixtures, valid Azure fixtures, missing prosody/phonemes | only dedicated scorer gets scoreState VALID; all absent metrics null |
| native credential | wrong model/config, multiple starts, expired token on active socket, resumption after expiry, lost mint response | deny/disable nativeLive if provider constraints do not enforce approved bounds |
| reservations | two devices concurrent start, crash before/after mint, ambiguous provider timeout, close/retry replay | one active slot, no budget refunds based on client claims, no duplicate mint |
| speech lifecycle | denied mic, Bluetooth, speaker echo, interruption, phone call, background, process kill, silence, slow network | stop mic/audio safely; typed/shadowing/turn mode fallback |
| latency | 30turns/mode/device; capture connect, final, first audio, barge-in; label network/provider/client contributions | report observed p50/p95 separately; no pass from mock timing |
| fallback | primary429/5xx/deadline then fallback exhausted | authored text+bundled audio remains; no paid adapter auto-enables |
| content abuse | learner prompt attempts to change key/model/tools; transcript injection | reference constraints preserved; no arbitrary tools/outbound URLs/private state |

P8 gate has two levels: baseline recorded/typed/shadowing+turn mode must pass; optional nativeLive/scoredPronunciation enabled only with account entitlement and physical evidence. Capability manifest reports exact disabled reason. A failed cloud optional capability does not block cached lessons or allow a false READY claim for that capability.
