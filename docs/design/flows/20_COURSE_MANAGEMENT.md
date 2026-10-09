# Course management and removal

Analyzed 2026-10-05 before implementation. Live Gummble: Removing a course
`02681cdc-5d55-4755-a529-9e6c7ecaf5c9` (5 screens). All cached source PNGs
were inspected at 1179x2556. The archive records an iOS capture with a 59px
top safe area and 34px bottom safe area, equivalent to a 390x844 logical
viewport at roughly 3x density.

## Source decomposition

- `sc_1cd2b55d47c740caa6b492a5c1ba3d33`: Settings entry context. Courses is a
  native row inside the rounded Account group; this route integration belongs
  to the parent slice.
- `sc_0d857b5fe2bd4edfb9f3bb5ca390f21d`: centered Courses header, gray back
  affordance near logical x26/y85, 1px divider, and a list with 8px horizontal
  margin starting near logical y132. The list has a 2px border, about 22px
  outer radius and 66px rows. Each row uses an 18px red remove control, a
  46x36 flag and a bold course label. The archived list includes French,
  Chinese, Indonesian, Math, Music and Italian.
- `sc_39a18bbd6e52469ea53842c8e2f55829`: confirmation sheet begins near source
  y1074 (logical y358), with a 36x5 gray drag handle. The sheet uses a centered
  24px bold “Are you sure?” title and 20px gray warning: “Be careful, deleting
  a course gets rid of all your progress and cannot be undone.” Crying Duo is
  bounded around source x440/y1670/w300/h350. A red tactile REMOVE action sits
  near source y2096 (logical y694), followed by a blue 16px CANCEL action.
- `sc_bb0631bc79284302b6116671568a935b`: the selected Italian row becomes
  visually disabled while removal is in progress. No duration or animated
  mascot state is established by this still.
- `sc_f537af1f44b94b5d9b798f0fc0fd7f42`: the list returns with Italian absent.
  The transition does not show a separate success message.

## Implementation contract

Native Flutter renders header, list, flags, sheet, copy and controls. A bounded
ROI supplies only the original crying-Duo still. Do not invent bounce or rig
motion from the archive. Narrow and text-scale-2 layouts scroll so sheet actions
remain reachable.

The local fixture seeds active English plus Chinese, Indonesian and Italian;
the archived Math and Music rows are excluded. English stays visible and
protected because the mock learning fixture depends on it. Attempting removal
shows that local-fixture reason. Cancel, back and drag dismissal leave enrollment
unchanged. Confirming a removable course removes it once; confirming twice or
targeting an already removed course is idempotent. A genuine synchronous local
removing state may be visible for one frame, with no fabricated server delay.
Course operations do not read or write learning XP, streak or path state.

Checks: controller removal/protection/idempotence, widget cancel/confirm/back,
360/430 widths at text scale 1/2, semantics, targeted analyzer and local visual
capture. Parent owns `/settings/courses` and Settings integration.
