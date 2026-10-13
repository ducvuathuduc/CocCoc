# Hearts and mock house ads (Slice A)

Owner rules: [DESIGN](../DESIGN.md), [gap rows 1–4 and 6](../GAP_AUDIT.md).
Archived iOS references supplied by the user; Gummble MCP is unavailable in this session.
Inspected all nine earn-heart captures, both hearts sheets and energy refill options.
Screen IDs: sc_1ae5ddcf, sc_fb07ca98, sc_ad9c3299, sc_fad12a43,
sc_2cdcb710, sc_365781ef. Screens are 1179×2556; divide by three.

- Lesson sheet: white bottom surface, 16px horizontal inset, gem balance at top right,
  centered 22px bold heading, two 174×258px option cards, 12px radius,
  selected Super gradient outline/check badge, disabled grey refill. Blue 48px
  tactile primary with 4px edge; NO THANKS closes and ends the session.
- Home sheet: centered two-line 22px title; next-heart countdown, 20px gap,
  three ~112×202px cards; practice selected. Super card has a gradient banner;
  refill grey when unaffordable. Practice primary, NOT NOW secondary.
- Earned heart: small heart count at top right; centered 178×145px red heart
  above 22px bold copy; bottom blue EARN 1 HEART play action, NO THANKS.
  Ad action is suppressed for Super/Max. Practice completion grants once per receipt.
- House ad: black/brown stage, title near y=190, character illustration below
  y=350, countdown at top left and mute control at top right. Final frame changes
  copy to Practice makes perfect. and reveals CONTINUE; skip appears after countdown.
  Still captures cannot establish actual duration: authored mock countdown 5 seconds.
  No SDK/network ad playback. Optional post-ad trial uses existing /super.
- Energy: retain all existing geometry and colors, default full state and golden.
  Repository supplies the three rows. Full/unlimited disables refills. Partial
  energy enables free +2, rewarded +5 and 500-gem recharge with affordability guard.

Motion: sheet entrance 300ms easeOut; reward scale 300ms easeOutBack;
reduced motion immediate. Timers stop on disposal/background. Native text only;
illustration crops exclude source text/numbers. Tokens reused from ReferenceColors
and LearningColors; any additional colors require source pixel coordinates.

The existing in-lesson `showOutOfHeartsSheet` remains wired and unchanged, as
requested by the owner after restart. The separate `showHeartsOfferSheet` is
reachable through a new tap on the failed unit/section-check illustration at zero
hearts; its existing Continue action and rendered geometry stay unchanged.
Swapping the in-lesson placeholder needs owner approval for one golden update:
`apps/mobile/test/goldens/ui_master/sprint_lesson_out_of_hearts_430.png`.
The home sheet is exposed standalone: existing checks start with five local
hearts and the home path uses energy, so there is no shared zero-heart start gate.
No device or live ad-service evidence is claimed by these widget checks.
