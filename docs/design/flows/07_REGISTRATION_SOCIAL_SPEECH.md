# Registration, social and speaking analysis

Inspected 2026-10-04 using live Gummble MCP before implementation. Original ordered manifests and bytes: references/signup, friends, delete, call. These archived iOS captures are source evidence; typography, forms, cards, messages, progress and buttons remain native Flutter. User requested a mock preview.

| Flow | Reference states and measured layout | Implementation decision |
|---|---|---|
| Signup | 01 offer with clipboard Duo, 02–03 age, 04–05 first/last name, 06–08 email including correction, 09–10 password/eye and green CREATE PROFILE; top back + green segment progress; 11 contacts primer, 12–14 selectable friend rows/busy, 15–16 finish | Four-step preserved form, validation and duplicate mock email. Local profile receipt followed by verification demo; friends accessible separately. No contact permission or actual email sent |
| Friends | 02 Following/Followers segmented header, native avatar/name rows; 03 empty followers; 04 follower/follow control. Signup12–13 selected/unchecked friend rows | Search/select/follow local fixtures, empty state, per-person profile, activity. No external invitation |
| Delete | 03 disabled timed CTA, 04 enabled, 05 confirm bottom sheet, 06 sad Duo/check-email receipt | Explicit local simulation with confirmation and receipt; no cloud account removal or email. Preserve preview identity/data |
| Call | 02 teal path offer; 03 black calling Lily, 04–05 large purple Lily illustration and red hang-up; 06 dark completion, 07 chat transcript review; 08–10 follow-up | Deterministic typed conversation with connecting/responding/reconnecting/ended states, native messages and hang-up. Original face illustration region only; speaking/result displays unscored without recorded media |

Media and permission state simulations are labeled. Do not animate a still and claim original lip-sync. Original Duolingo web Lottie is used where identified; archived iOS call phoneme motion needs a source timeline. Reminder/sync/verification/error layouts adapt established native account and sheet components; they are not claimed as Gummble-exact captures. Routing follows the canonical screen inventory and preserves bottom-tab stacks.
