# Login and recovery reference analysis

2026-10-04. Written after visually inspecting all ordered screens and before replacing the login placeholder. Explicit user choice: preserve Duolingo appearance, copy, Duo and icons. Source manifest: [screens](../references/login/manifest.json). Native status bars/keyboard follow the running OS.

## Ordered login flow

Gummble flow `ad65004b-d8d7-4b8a-b3fb-3a548882b2f9`, six screenshots.

| Ref | Screen and hierarchy | Layout/state | Action and implementation |
|---|---|---|---|
| 01 | Welcome: Duo, wordmark, tagline, two CTAs | Center illustration, bottom green Get started and outlined existing account | Reuse onboarding welcome; existing account opens login choice |
| 02 | Already have an account? / New to Duolingo? | Back at upper left; two centered sections; divider; green Sign in and outlined Get started | Sign in opens details; Get started starts onboarding; Back returns welcome |
| 03 | Enter your details, empty | Gray title centered in 48px header; joined rounded input panel; disabled sign-in; blue Forgot password; bottom Google/Facebook/Apple rows and terms | Autofill, keyboard Next/Done, hidden password toggle, disabled until both fields filled |
| 04 | Enter your details, filled | Same layout; sign-in blue with dark blue bottom edge; entered identity shown, password hidden | Asynchronous repository command; prevent duplicate submit; preserve input on error |
| 05 | Signing you in | Duo reading books centered, uppercase gray caption below; no form | Busy until backend completes; failure returns to populated form; no arbitrary success timer |
| 06 | Learning path after success | Course status, unit banner, path, bottom tabs | Destination evidence only. Learning path is a later task; this slice shows a verified sign-in confirmation and onboarding/lesson boundary instead of invented progress |

## Saved and other-account branches

Saved flow `5a0502bf-5922-44f1-a529-70f3f03184c7`: ref07 waving Duo / Sign back in / account row with initial, name, email, chevron / Add another account / Manage accounts; ref08 reading Duo busy; ref12 learning-path destination. New-account login flow `85a30736-0e4c-4f18-804d-fcdd611a1faa`: ref07 chooser → ref09 account-choice variant without subtitles → ref10 empty form with Email or username → ref11 filled form → ref12 path. Sample identities in references are fixture data only. Production chooser uses only metadata returned by a verified account; selecting remembered email still requires authentication. Manage removes the remembered account entry, never silently deletes a cloud account. No password/token is put into preference storage.

## Recovery flow

Flow `80a70211-7d97-4806-9843-db071f4e16b4`, six ordered screenshots: populated details (ref11) → Forgot password (ref13) → Check your email sheet (ref14) → Reset your password empty (ref15) → filled (ref16) → Success sheet (ref17).

| Ref | Deconstruction | Behavior |
|---|---|---|
| 13 | Back; left heading Forgot password?; single pale input; muted two-line explanation; blue Next fixed near bottom | Prefill typed email; validate email; async recovery request; retain entries on failure |
| 14 | Dimmed form; rounded sheet with handle; centered title/body, bold email; blue Okay | Show only after successful request. Use neutral delivery copy to avoid confirming account existence; dismiss back to populated form |
| 15–16 | Back; centered Reset your password; joined new/confirm fields with eye icons; fixed bottom disabled/blue CTA | Require ≥12 characters per SRS and matching confirmation; request requires backend-issued userId and secret from recovery link; no client-side success simulation |
| 17 | Dimmed destination; celebratory Duo holding phone; Success, explanation, blue continuation | Only after backend update succeeds; clears password fields; returns to sign-in without fabricating an authenticated session |

## Implementation boundaries and acceptance

Feature-first manual Riverpod MVVM; immutable auth UI state/controller, repository and Appwrite SDK service. Appwrite owns Account endpoints, per [auth contract](../../api/AUTH.md). Only email/password is supported by the frozen SRS; the reference phone/username hint is narrowed to Email, with the identical field appearance. Provider rows preserve reference artwork; commands explain unavailable providers until explicitly configured. Apple eligibility/configuration remains required. No keys in the mobile app; endpoint/project are public build configuration. SDK27.0.0 targets Appwrite Cloud2.3.x ([publisher](https://pub.dev/packages/appwrite), [Account API](https://appwrite.io/docs/references/cloud/client-flutter/account)); no live cloud mutation was used for UI tests.

Acceptance: Back preserves typed fields within flow; password visibility does not submit; busy blocks duplicate commands; empty/invalid email stays local; failure never clears input; recovery success never appears on failure; verified account required for production success; saved chooser contains no reference sample identity in production; system Back, keyboard and text scale2 remain usable.

2026-10-04 user override: mock data first to finish UI. Debug builds select `MockAuthRepository` by default; release builds require explicit `USE_MOCK_AUTH=true` to opt into that demo. Demo email is `demo@cocenglish.test`, password `duolingo-demo`. All three social buttons simulate the same demo account. Mock recovery's Okay opens the reset preview with demo-only tokens; reset updates the in-memory demo password, then returns to sign-in. No email is sent, OAuth browser launched or cloud account mutated. These mock commands do not change the production identity contract. Saved demo metadata persists only for the current repository instance; passwords are never written to preferences. The destination is a clearly scoped frontend welcome/lesson boundary, not the unimplemented reference learning path.
