# Slice B: offline path and XP boost activation

Sources: archived Gummble iOS captures supplied in [gap refs](../refs/gap/),
1179×2556 at 3×. Live Gummble tools were unavailable in this session.
Design and motion owner: [DESIGN](../DESIGN.md).

- `sc_12b09a6c`: banner below the status bar, crossed cloud and white
  `YOU ARE OFFLINE` caption, centered with 8 logical px between icon and text.
  Grey sampled at `(20,200)` = `#CCCCCC`; inactive path at `(350,1080)`
  = `#F3F3F2`. Keep the existing unit header and current node colored;
  wash inactive nodes/mascot/stars to grey and render the streak grey.
  Online geometry and art must retain the existing golden.
- `sc_269d6ffb` / `sc_b4ac42c6`, Friends Chest flow `f6869640`: full purple
  screen; flask bounds approximately `(401,718)`–`(781,1168)`, `x2` below,
  centered two-line activation copy starting at y=1519. Duration highlighted
  gold; white Continue bounds `(48,2261)`–`(1131,2394)` with 12px lower edge.
  Divide source coordinates by 3. At 360px, scale reference spacing by 360/393.
  Larger text scrolls above the pinned Continue button instead of clipping.
  Flask graphics use the already bundled shop XP boost art, clipped to its
  silhouette at paint time; copy and multiplier are Flutter text from the repository model.

Motion is authored, since archived stills cannot establish timings: banner
height changes over 250ms easeOutCubic; reward entrance 300ms easeOutBack;
decorative floating bubbles loop slowly and pause with the app. Reduced motion
renders immediately and stops repeating animation. No animation grants XP.

Connectivity uses a repository stream and its current value; mock starts online.
API transport failures signal offline and subsequent HTTP responses recover.
This is observed API reachability, not OS connectivity or a background probe.
Boost activation has mock and API repositories; the API derives duration from
the server timestamps. The Friends Chest mock supplies the 2×, 15-minute reward.
