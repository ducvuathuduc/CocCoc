# PAR_STATUS — profile tab slice (branch par/profile)

## Scope
Profile tab: profile header, stats, achievements, friends, share link.
Refs: docs/design/references/profile/*.png (all 8 viewed).
Out of slice: 01.png (learn path), 02.png (overflow menu w/ Profile entry) —
owned by path/menu slices.

## State coverage vs refs
- 03.png avatar creation sheet -> showAvatarCreateSheet (START / MAYBE LATER)
- 04.png new-user header/counters/finish card/overview -> profileMockNew
- 05.png friend-streak invites, locked monthly badges, locked achievements
- 06.png rich header, MAX badge, +7 courses chip, Sapphire/top-finishes overview
- 07.png friend streaks + MAX FAMILY + MANAGE -> fixture-driven family section
- 08.png earned monthly badges + achievements w/ NEW + counts -> rich fixture
- Share link (QR + copy confirmation) per 21_PROFILE_ACTIONS refs.

## Changes (this turn, on top of existing slice scaffold)
- test: fixed share-sheet COPY LINK tap (ensureVisible; single pump for SnackBar)
- lib: fixed Courses flag rendering empty (Row crossAxis stretch)
- lib: MAX badge + fixture-driven family (showMaxBadge/showFamily/familyMembers)
- lib: application/profile_controller.dart (Notifier variant + active profile)
- lib: presentation/profile_tab_page.dart (ConsumerWidget page)
- test: +2 Max/family visibility tests, +page/controller switch test
- QA FIX (lead QA 05:05 vs 03.png): bust-silhouette empty avatar w/ full-contour
  dashed outline + white plus (150x180, open at header edge); avatar area 147->210
  bottom-aligned; flag chip deep tones #1C6FA1/#A3302D; avatar-sheet goldens added
  (ensureVisible for textScale 2)
- test: new test/features/profile/profile_avatar_sheet_golden_test.dart (4 goldens)

## Evidence
- `flutter analyze --no-pub --fatal-infos` -> No issues found
- `flutter test --no-pub test/features/profile` -> All tests passed (22: 10 widget + 12 golden)
- Goldens: apps/mobile/test/goldens/ui_master/profile_{new,rich}_{360,430}_text{1,2}.png
  + profile_avatar_sheet_{360,430}_text{1,2}.png
- textScale 2: bounded ellipsis, no exceptions, ADD FRIENDS/COMPLETE PROFILE reachable

## QA FIX REQUIRED
(resolved 05:05 items 1-5: bust placeholder + header proportions + avatar-sheet
goldens + deep flag tones; header hero stays light-blue per 04.png — the muted
tone in 03.png is the modal scrim over the same header)

TICKET DONE
