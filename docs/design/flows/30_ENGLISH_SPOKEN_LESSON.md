# English speaking and Lily reply — 2026-10-09

Scope: the existing English lesson engine, its answer states and first result
screen. No new subject or foreign-language curriculum. Reuse completed path,
guidebooks, retry loop and subsequent reward states.

## Live reference analysis

Gummble MCP returned the ordered Starting a lesson (33 states) and Completing
a lesson (13 states) journeys. These are reference occurrences, not 46 new
product flows. Six key source screens were visually inspected before changes.

| Source screen | Native adaptation |
| --- | --- |
| sc_c7b79d960e9c48caabd606f79268d1cf | Respond to Lily: bordered audio bubble, centered full character, bottom speech alternative. English prompt replaces the source French prompt. |
| sc_6d64b91d069a4a50a74981811fddb082 | Correct Lily feedback exposes an authored Vietnamese meaning. Original Lily Rive reset/correct/incorrect inputs drive reactions. |
| sc_b52c1f93ecd7403fb6002fa837ff4056 | Speaking: three stacked word cards and a blue audio-wave action. The English repeat exercise uses its own sentence. |
| sc_bab6c64dec12434297fede3f7c0bef68 | Actual consecutive correct answers produce a streak header and orange progress. No copied fictional 17-answer count. |
| sc_23afb65ade9a45f19dba4cf32e1fd5ab | Result: original medal Duo, yellow heading, three actual metric cards. Native wrapping at 320 logical pixels and large text. |
| sc_3dbac870c7ff43b098c0d2ab535f5663 | Existing English score unlock is retained; no second score implementation. |

The 1180×2556 Lily still has a character region x=426, y=930, width=330,
height=690, including its shadow (visual bounds rounded outward). At 390 logical
pixels the region is 109×228. The untouched original PNG is bundled; ReferenceArt
paints only this region. Audio bubble uses native 2-pixel border, 20-pixel radius,
48-pixel audio action and wrapped text. The result illustration preserves its
source aspect ratio. Fonts and button depth reuse the project design system.

## State and capability contract

- Lily: ready → unavailable speech/audio notice or text alternative → checking
  → correct meaning/incorrect correction → next exercise or existing retry.
- Speech fallback preserves exercise ID, expected answer, meaning and draft;
  repeated fallback cannot erase typed input. No answer is graded on a media tap.
- Pausing preserves the alternative and draft. New exercises reset the
  alternative. Successful grades update actual streak; wrong grades reset it;
  failures retain it. Local receipt metrics remain the source for results.
- Original exported Lily Rive is used through the existing lifecycle-safe
  CharacterMotion. Reduced motion renders the inspected still. No fabricated
  lip sync, private confetti timeline or screenshot-only motion claim.
- Native frame measurement found Lily's exported artboard draws its body at
  roughly half the fallback height: a 112×234 viewport had purple-body bounds
  x=510..668, y=1304..1626 at 1180/390 capture scale. The inspected lesson applies
  2× render scale with vertical alignment .19 to compensate this original
  padding; fallback dimensions remain unchanged. Other characters keep their
  existing render scale. Final native purple-body bounds x=430..747,
  y=1109..1754 verify the correction alongside the recorded measurement.
- Authored English/Vietnamese content, local grading and text fallback are in
  scope. Live recording/audio services remain unavailable; notices state that
  clearly without engineering/demo copy in the learning screen.

Sources: [Starting a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=55608180-814c-4cfa-b79c-982af1c8a797), [Completing a lesson](https://gummble.com/apps/duolingo-ios?tab=flows&flow=238c4339-7173-4257-89c5-2716a8a68c44), [original Lily still](https://storage.gummble.com/prod/content/app_screens/598cc547-5ac1-4b9a-8a62-e594b6e2ec2a.png).
Exact ordered journey IDs and original source URLs remain in
[ORDERED_FLOW_INDEX.json](../references/ORDERED_FLOW_INDEX.json) and the hashed source cache.

Verification receipt: [ENGLISH_LESSON_REPORT.md](../qa/ENGLISH_LESSON_REPORT.md).
