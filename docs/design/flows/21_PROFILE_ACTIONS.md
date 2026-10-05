# Profile options, reporting and profile link

Analyzed 2026-10-05 through live Gummble MCP before implementation. Reporting a
user `df57517c-845f-4cd4-b910-eea2fb965672` has three ordered screens;
Copying a profile link `30b7b0ec-8359-4d2a-99c3-618a964a9833` has three.
References are1179×2556; use390logical width and59/34safe areas.

- `sc_9042f4fee7a6438e9757c1115227cc15`: profile context/options entry.
- `sc_869490f9091b4610841aa22ef3c192c4`: iOS action sheet over native profile;
  explanation13px gray, three57px rows22px system blue: Nudity, Spam, Something
  else. Separate Cancel57px. Native translucent surface,12px radius,8px margins.
- `sc_b84c09f0db8c4f74be1f0506c6b1e928`: profile result showing UNBLOCK USER.
  The archived flow couples the result with blocking; the local preview explicitly
  labels its report/block confirmation and never transmits a report.
- `sc_4dda25e955744c808ff9faf4702732ca`: own-profile share entry.
- `sc_ca5e8f65569347e0b706ed65036796f7`: centered rounded white dialog at
  x41,y161,width308,height526logical; close atx77,y199,24px name,16px handle,
  round-module QR approximately264px, logo and two tactile icon controls with
  native labels Share link / Copy link.
- `sc_1a8c95e2a8214aaaab55752c0004f486`: same dialog plus bottom native toast
  'Profile link copied'. Preserve the dialog after copy.

Implementation: a separate Riverpod mock controller owns validated profile IDs,
idempotent report/block/unblock state, and asynchronous clipboard failure/retry.
Profile actions reuse the existing native profile rather than rebuilding it.
The generated QR and clipboard refer to the same local `cocenglish.test` preview
URL, not the archived person's real link. Share opens a local preview; no message
is sent. Clipboard itself uses Flutter's platform service and is tested via an
injected writer. Original avatar/logotype art is reused; native text/controls and
QR are not flattened screenshot UI.

QR rendering uses pinned qr_flutter4.1.0, verified against its
[official API](https://pub.dev/documentation/qr_flutter/latest/qr_flutter/):
circular data modules, high error correction and a quiet zone. Exact rounded eye
geometry and the source QR's encoded contents differ. No decorative mascot motion
is shown in these archived action sheets; none is invented.

DoD: cancel/back has no side effect; invalid/own IDs cannot be reported; repeat
report cannot duplicate; unblock does not auto-follow; clipboard failures preserve
the dialog and permit retry;360/430×text1/2 plus source-sized captures reviewed.
