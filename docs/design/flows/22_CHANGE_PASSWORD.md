# Changing password

Analyzed through live Gummble MCP on 2026-10-05 before feature code. Flow
`5985148c-6771-40a1-b8ff-648fad04a7eb` has four ordered iOS screens:

- `sc_198760c7ea104d109c8f52a26b96e152`: profile editor; password row opens
  the change screen. Source editor includes first/last name, username, email,
  phone and avatar. The native source form now includes those fields and the
  original avatar entry. Password navigation preserves the unsaved Profile draft;
  validation errors preserve input and profile updates are atomic locally.
- `sc_7c2c392213fb445baf4c823cc5706781`: empty Password screen, left gray X,
  centered 20px bold title, 16px horizontal margins. Three 18px bold gray labels
  Old password / New password / Confirm password. Fields approximately48px high,
  12px corner radius, light gray fill, 2px border and blue visibility controls.
  Bottom full-width SAVE is disabled gray; white background and iOS safe areas.
- `sc_24d188fef2c04aa3b15e83003cb3d8a1`: completed fields enable blue SAVE.
- `sc_846d595f59834ce590752ad844a61d2e`: successful save returns to editor.

Native fields use bundled DuolingoSans and the shared tactile button. Keyboard
and text scaling scroll the fields; each visibility control is independent.
Mock saves validate the old password and update only the current in-memory mock
account, so subsequent mock login uses the new value. Preview-only fallback uses
the demo account when no saved mock login exists. Existing 12-character password
policy applies. Failure preserves all three fields; busy prevents duplicate
commands. No password is logged, persisted to disk, included in coverage or sent
to Appwrite. Real account update is a pending production capability.

No mascot or additional animation is visible in these password references;
reuse shared button/route motion, with reduced-motion support. Exact iOS route
timing is not established from screenshots.
