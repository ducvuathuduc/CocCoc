# Max — English mock flow

Analyzed before implementation,2026-10-04. Live MCP refreshed individual flow
`6f140793-7376-4497-8a35-0b8274bcdff4` (14 steps) and family flow
`f87edc8e-f6da-469b-b407-5cbdab5adc35` (12 steps). All individual states and
family reminder/selection/welcome/invite/call/completion states were opened.
Cached IDs and original dimensions are in the ordered reference index.

Sequence: subscription offer → Max benefits → Free/Max comparison → reminder
choice (2 or3 days) → annual Individual/Family selection → local checkout sheet
→ local success → welcome → feature tour → completion → English path.
Back/close preserves the pending selection and reminder. Dismissing checkout
must not activate a plan. Only an explicit mock confirmation changes local
entitlement; cancellation clears Max and family invitations. No store SDK,
payment, OS notification or app-icon mutation is performed.

Native widgets own titles, rows, progress, selection badges, buttons, sheet and
switch. Original image ROIs supply Lily's phone, six feature icons, black Duo,
family cast, reminder bell, tour phone/benefits and Max app icon. Black Duo is an
original still: the green Duo timeline and exercise Lily rig are incompatible.
No invented lip-sync/black-Duo motion. Transitions respect reduced motion.

Archived prices: Individual $167.99/year, $13.99/month equivalent; Family
$239.99/year, $19.99/month equivalent. These are fixtures, not current offers.
Use English course copy in place of captured French. Replace archived dates and
account email with local preview copy. The checkout clearly says it is simulated.

The archived individual tour exports steps1,4,5 only. Two bounded MCP searches
returned subscription pages, not the missing tour2/3 artwork. Explain/Roleplay
tour pages therefore use verified feature icons and native explanatory copy;
their exact original scene/layout remains unverified. Family additionally has
verified invite and completion art. No claim of complete pixel or motion parity.

Official product drift: [Duolingo's current explanation announcement](https://blog.duolingo.com/explain-my-answer-now-free/)
says Explain My Answer is free; this implementation reproduces the archived
Max visual hierarchy while leaving lesson explanations available without a plan.

Verify complete routed selection/checkout-dismiss/confirm/tour/cancel sequence,
family capacity, text1/2 at360/430, semantics, source-sized captures and web.

2026-10-05 review fixes: platform Back after confirmation resumes the same tour through Max entry; completion is explicit, and cancelling an active Max plan resets the old reminder, plan and tour draft. Pre-confirmation dismissal preserves choices. Native progress now uses the measured thin bar and circular number markers from the archived call capture; the illustration starts lower to retain the source's title-to-character spacing. Native gradient and opaque source-ROI edges still require exact fidelity review. App-icon selection changes only local preview state.
