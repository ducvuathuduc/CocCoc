# Saved account management

Analyzed 2026-10-05 before implementation. Live Gummble: Removing a saved
account `7f823279-b5f5-46df-91a4-982c7f915182` (4 screens), iOS, archived at
1179/1180x2556. The references establish a local remembered-account edit flow,
not production account deletion.

## Source decomposition

- `sc_19578555f1df45fda7a65c3c0e866dda`: Sign back in entry with original Duo,
  a joined saved-account/Add another account card and gray MANAGE ACCOUNTS.
- `sc_e062370e3afc454ab40d27be92f5a05a`: native white management screen. The
  centered “Manage Accounts” title begins near logical y112. A rounded gray
  account card begins near y168 and contains a red minus, green initial circle,
  bold name and gray email. Green DONE EDITING sits near y295.
- `sc_229da631786e4c809e6ca42c72aa6f84`: tapping the minus opens an iOS anchored
  popover above the control with one red Remove action. The source shows a
  translucent liquid-glass surface and background bloom. Its exact blur,
  compositing and animation are not available as reusable Flutter assets.
- `sc_6b0fe96d8c1f4448a9ef2eba9f75b489`: successful removal returns to the welcome
  entry. No completion toast appears.

## Implementation contract

Flutter renders all text, card, minus control and anchored popup natively.
The popup uses an opaque rounded surface with border/shadow because archived
liquid-glass blur is platform-specific and not established by the project
tokens. Outside tap, Back and DONE EDITING preserve the remembered account.
Remove calls the existing `AuthController.forgetRemembered`; duplicate removal
is disabled while busy. Only confirmed success returns `true` to `LoginFlow`,
which invokes its existing exit callback so the application returns to the
existing welcome screen shown by source step 4. Done, Back and popup dismissal
return no success result and preserve the remembered account. Failure keeps the
manager open and shows the existing controller error without losing saved
account data. Small-width/text-scale-2 layouts scroll rather than clip.

This slice does not alter auth persistence, repositories, routes, credential
input or server account data. Math and Music are unrelated and absent.
