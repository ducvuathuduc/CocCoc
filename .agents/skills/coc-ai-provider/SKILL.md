---
name: coc-ai-provider
description: Add or repair a CocEnglish AI or speech adapter with verified provider limits, secret boundaries and honest nullable assessment.
---

Trigger: assigned provider/live/assessment task in phase8 or later.
Inputs: capability, exact model, allocation, adapter contract and allowed tests.
Read: AI_ARCHITECTURE, AI_EVIDENCE, AI_EVALS, OpenAPI, nearest AGENTS and COST_MODEL.
Procedure: verify current official model/transport/token fields; record checked date/status/cost; implement one adapter behind interface; failing fixture tests for invalid output/429/timeout/expiry/ambiguous mint; preserve budget and active-slot invariant; implement authored/turn/shadowing fallback; run deterministic suite. Live test only within existing authorized allocation and outside CI.
Output: adapter diff, capability flag evidence, updated dated research if changed.
Validation: keys server-side, fixed model/config/expiry, no client refund/remint, no score without dedicated validated scorer, capture/playback lifecycle on actual device for enablement.
Prohibited: generic STT as phoneme grading, invented latency, automatic paid fallback, provider logic in views, unbounded raw audio storage.
