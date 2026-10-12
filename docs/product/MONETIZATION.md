# Commercialization and billing contract

Current coursework baseline: core language learning always works without a purchase account; Super/Max/family/cancel screens are fixture previews. No live billing dependency or credentials were added. Live implementation is gated after core learning/progress, with its own acceptance task and platform access. Design owner is this document; no duplicate billing architecture file.

Primary later adapter: maintained Flutter [in_app_purchase](https://pub.dev/packages/in_app_purchase), platform Google Play first and StoreKit for iOS. Progress owns entitlements/purchase receipts; AI consumes an entitlement decision through Progress API rather than reading/writing its tables. Provider secrets/customer verification keys never reach Flutter. RevenueCat is optional only when integration effort and actual current price justify a reviewed change.

[Play backend guidance](https://developer.android.com/google/play/billing/backend) requires secure server purchase-state processing; [subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions) treats current subscriptionsv2 state as authority. A client “purchase succeeded” message and RTDN alone are hints. Deduplicate messageId, verify authenticated notification transport, fetch purchase token state, verify package/product and user binding, then transactionally write receipt/entitlement. Never accept client price/expiry or acknowledge a pending purchase as active.

| State / event | Entitlement / UI / acceptance |
|---|---|
| purchase pending | Free remains available; show pending; no premium; pending→active only after verified vendor response |
| active / grace | Grant verified plan until authoritative boundary; test grace-specific policy without assuming all stores match |
| hold | Disable premium; preserve learner progress; offer manage-payment action |
| canceled | Keep access until paid expiry when vendor says active; cancellation does not mean immediate expiry |
| expired / revoked / refunded | Revoke premium idempotently; no fail-open; cached entitlements have short expiry |
| duplicate/out-of-order RTDN | Re-fetch current state; same logical grant/revocation once; older event cannot restore revoked access |
| reinstall / restore / user switch | Discover owned platform purchases, reverify and bind to correct account; never transfer another learner's entitlement |
| app killed after checkout | Backend reconciliation plus restore recovers; fixture reproduces without real checkout |
| vendor/queue outage | Keep free learning; show premium verification pending; safe retry, audit receipt and alert |

Local fake billing adapter must use `isSimulation`, fixtures for every state, no actual purchase token and no production entitlement write. Add platform sandbox/test purchase gates before real money. Play Console registration, Apple membership/signing and API eligibility are separate account costs, unverified here; do not include them in a zero-new-spend claim. No legal/licensing essay or production checkout is included.

```mermaid
sequenceDiagram
  participant M as Flutter
  participant S as Platform store
  participant P as Progress
  participant V as Vendor verification API
  M->>S: Start purchase
  S-->>M: Pending or purchase token
  M->>P: Authenticated verification request
  P->>V: Fetch current purchase state
  V-->>P: Authoritative state
  P->>P: Commit receipt and entitlement
  P-->>M: Verified plan or pending
  S-->>P: Authenticated RTDN hint
  P->>V: Reconcile current state after dedupe
```

## Decisions 2026-10-12 (user): mock billing, promo codes, mock ads

- **Billing stays mock.** P10-BILL-001 implements a server-side *mock billing provider* in Progress. It records `p_purchases` with platform `SIMULATION`, steps through the state table above from fixture outcomes (pending, active, grace, hold, canceled, expired, refunded and duplicate notification) and writes `p_entitlements` plus `entitlement.changed.v1` atomically through the same verifier path a real store would use. No Google Play Billing or StoreKit client, store credentials, purchase tokens or real money. The Platform store and Vendor API in the sequence above are replaced by the mock provider. Real stores require a new, explicitly authorized task.
- **Promo codes** (P10-PROMO-001; tables `p_promo_codes` and `p_promo_redemptions` in [DATA_MODEL](../data/DATA_MODEL.md)). A code grants Super days (`p_entitlements` source PROMO), gems or a catalog item, once per user. Each code has a validity window and an optional global redemption limit. Codes are created by the maintainer CLI and stored only as hashes. The redeem endpoint is proposed in [API_ENDPOINT_MATRIX](../api/API_ENDPOINT_MATRIX.md#proposed-endpoints).
- **Ads are mock, free tier only** (P10-ADS-001; table `p_ad_events`). The placements are a lesson-end interstitial, rewarded gems and a rewarded energy refill. Ads are suppressed whenever the entitlement plan is SUPER or MAX, never gate or interrupt core learning, have per-day caps, and grant each rewarded completion exactly once. No ad SDK, ad network, tracking identifier or revenue is integrated. The client shows a local mock ad surface.

OpenAPI has no enabled billing endpoints yet. Add versioned DTOs/tables through contract-owner review before implementation; this design does not silently expand service write scopes.
