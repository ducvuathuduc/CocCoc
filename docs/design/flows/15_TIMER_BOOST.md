# Timer Boost — archived iOS reference, English challenge preview

Analyzed 2026-10-05 before implementation. Live Gummble flow: [Purchasing a timer boost](https://gummble.com/apps/duolingo-ios?tab=flows&flow=d3738966-0f4b-4bc8-bf81-750c2a5854b7). Five cached 1179×2556 source images were inspected in order; selection and success images were inspected again through MCP at high quality. These are archived product captures, not current pricing guarantees.

| Source state | Native implementation and action |
|---|---|
| `sc_3090b39d7eec48e69a1aa1e3cb64dd40` Shop, wallet1035, boost×1 | Shop stock card opens a rounded, scrollable offer sheet. Wallet and stock derive from the same local preview ledger. |
| `sc_f41ad70e7d79482f93efcbabc88cbe96` default5pack | Three selectable native cards: single450,5pack1800(previous2250),15pack4500(previous6750). Popular badge and native purple tactile CTA. |
| `sc_8f2ba5a12fd948d980df540dae6da970` single selected | Purple checked outline; fixed original clock/basket/barrel illustration regions. Selecting a pack never spends gems. Dismiss retains selection. |
| `sc_bbd3e1204a6548d99ef34308b47c4b3b` success | Blue page, original clock/rays illustration, native stock count, native `Timer Boost +N`, white return CTA. Purchase atomically changes stock and wallet once. |
| `sc_0d86633c11584220a996db8f3767b850` Shop, wallet585, boost×2 | Return shows the updated local ledger. |

Reference sheet begins at sourcey672; the native modal occupies74%of the viewport, with20px logical corners,16px side margins, approximately86px choice-card height, and44px button height. Heading has a310px logical maximum width and uses DuolingoSans bold; all labels/prices remain native widget text. Source files remain byte-identical; only bounded illustration regions are painted. Success clock/rays are a single illustration, not a screenshot containing controls. The inventory icon uses the original blue-background source region to avoid a white square.

The preview starts with5earned gems. An explicitly labeled `USE DEMO BALANCE` error action can top up to1035 once for testing; this is authored preview behavior, absent from the reference. Insufficient funds preserve selection, balance and stock. No checkout, charge or production reward command exists.

Rapid Review expiry can consume one owned boost for60foreground seconds while preserving question, choices and feedback. A second tap after resuming cannot consume another boost. Purchase from an expired challenge returns to that same challenge; applying the owned boost is explicit. Background/TickerMode pause rules remain unchanged. This connection is an authored mock behavior because the five source captures show purchase only.

Motion: native sheet transition and existing tactile button animation. Source screenshots do not prove clock rotation or success timing; no proprietary boost animation is claimed. Reduced-motion/static illustration rendering, narrow/wide text-scale2, dismissal, insufficient funds, duplicate purchase and expired-question preservation require tests and visual inspection. Exact whole-Shop layout and pixel/motion sign-off remain open. See [current verification receipt](../qa/ENGLISH_EXTENDED_REPORT.md).

Actual narrow text-scale2 purchase testing exposed Home status-row overflow after its wallet increased. Home now wraps the native status controls when needed and derives the same wallet as Shop. Modal dismissal, purchase-success return, double-tap expiry guard and foreground/background timer restart are covered by routed widget tests. Full-screen render fixtures additionally cover360/430 × text1/2; they do not replace the actual narrow modal check.
