# Draft ADR-0019: Descope identity with existing Flutter UI and owned Appwrite data

## Status

**NOT ADOPTED / CLOSED FOR CURRENT SCOPE, 2026-10-25.** After evaluating migration impact on OTP and password recovery, the human chose to retain the existing Appwrite Auth integration. Do not add Descope SDKs, token exchange or identity mapping for this implementation. Appwrite identity/session/account IDs and approved UI remain the active baseline. ADR-0018's Docker/RabbitMQ/Redis/GitHub Actions implementation direction remains approved independently.

The evaluation below is retained as historical technical context only. Reopening it requires a new explicit provider-change request, not an assumption that the earlier question authorized migration. No Descope account, session or live project configuration was changed during evaluation.

## Context

Auth already exists as managed Appwrite Auth. Learning, Progress and AI are the three business services; this count excludes managed identity infrastructure. Backend `services/shared/src/auth.ts` exposes `AuthPort.verify(jwt): Promise<VerifiedSubject>`, where `VerifiedSubject` contains the app's `userId`. Its current implementation verifies an Appwrite account and constrains user IDs to 36 characters. Flutter already has `AuthRepository`, `AuthSessionRepository` and `EmailCodeAuthRepository` ports.

Descope can replace the user-facing identity provider without introducing a fourth business domain or changing the approved screens. Existing profile, progress, reward, session, deletion and cache namespaces must retain the same canonical app user identity. A Descope subject is not assumed to be an existing Appwrite user ID.

## Decision — retain Appwrite Auth

Reuse existing Flutter Appwrite auth repositories and the backend verified-Appwrite-JWT adapter. The current email-code flow calls `createEmailToken` then `createSession`; password recovery calls `createRecovery` then `updateRecovery`. The latter requires a configured HTTPS `APPWRITE_RECOVERY_URL` and a tested allowed callback/deep-link path. Existing code is not proof that actual email delivery, expired/used codes and device callbacks passed live acceptance. Preserve those acceptance tasks in the real-feature plan.

## Historical Descope candidate

- Prefer the native/headless `descope` Flutter SDK behind current auth repositories. Keep all approved Flutter layout, copy and motion. Use the SDK's password/OTP/OAuth APIs for existing actions. New passkey/MFA flows require actual product/UI scope, not merely SDK availability.
- Use `@descope/node-sdk` behind the existing backend AuthPort if selected. Validate session tokens on each private request with the configured project/audience, signature, issuer and expiry policy; use bounded key refresh/cache and fail closed on unverifiable tokens. The provider adapter must return canonical app identity, never a caller-supplied user ID.
- Keep authentication separate from app authorization: Progress owns profile/privacy/blocks/entitlements; Learning owns enrollment and sessions; AI owns provider eligibility/quotas. Descope roles/claims do not grant XP, gems, subscriptions or private row access by themselves.
- Reuse the SDK's session persistence/refresh/logout primitives, with tested platform secure storage and disposal. A local JWT signature check does not establish immediate global logout/revocation; specify the accepted revocation window and enforce app deletion/tombstones independently.
- Keep public project identifiers in config; management/server keys remain outside mobile, source control, Docker images and ordinary PR jobs. Client-requested insecure/custom `nsec` claims cannot authorize business operations.

Official integration references: [custom-UI mobile SDK](https://docs.descope.com/mobile-sdk), [Flutter SDK](https://github.com/descope/descope-flutter), [password APIs](https://docs.descope.com/auth-methods/passwords/with-sdks/mobile), [Node session validation](https://docs.descope.com/getting-started/nodejs), [mobile session management](https://docs.descope.com/sessions/management/mobile).

## Alternatives and Appwrite boundary

| Option | Consequence |
|---|---|
| Keep Appwrite Auth | Current implemented identity path remains unchanged; no provider migration. |
| Descope identity; business APIs use existing server-side Appwrite adapters | Recommended architecture to evaluate first. Services validate Descope and enforce canonical app identity/ownership, then use allowlisted server credentials for their own data. Direct private Appwrite client reads/Realtime require a separate compatible session mechanism or existing authenticated API polling. |
| Descope identity plus explicit Appwrite custom-token/session bridge | Appropriate if native clients must retain Appwrite-user permissions or private Realtime. Verify Descope first, map to a canonical Appwrite user, issue a short-lived Appwrite custom token using the server SDK, then exchange it for an Appwrite session. Adds a second session lifecycle and logout/deletion reconciliation; never accepts a user ID from the client as proof. |

Do not pass a Descope JWT directly as `X-Appwrite-JWT` or to the current Appwrite `Account.get` verifier. A third-party token is not an Appwrite session token. Appwrite documents an explicit [custom token flow](https://appwrite.io/docs/products/auth/custom-token) for external providers. The server-side adapter option above is an application architecture recommendation; it is not a claim that Appwrite natively trusts Descope JWTs.

Do not select or implement the bridge implicitly. Inventory actual direct private SDK/Realtime use and choose one consistent session architecture first. Keep current Appwrite auth active until the chosen provider path passes acceptance.

## Migration and rollback

1. Record the admitted Descope project, supported auth methods, callback URLs, Android package/signing identity, native SDK versions and secure-storage behavior. Preserve the mock browser preview. Confirm actual Flutter Web support before promising a real web build; the native mobile SDK alone does not establish it.
2. Define a durable unique mapping from trusted issuer/project plus Descope subject to canonical app user ID, owned by the identity/profile boundary. Preserve existing IDs for linked users; do not truncate provider subjects, collide IDs or automatically merge accounts by email. Existing-account linkage requires verified proof of the existing identity and the new identity.
3. Complete contract/schema/permission work for mapping or an Appwrite bridge before enabling it. Keep identity resolution read-only in shared AuthPort; shared transport does not acquire business-table write ownership.
4. Implement Flutter and backend adapters against the same provider/issuer/audience contract. Keep the old provider selectable only through explicit environment migration policy; token acceptance never trusts an issuer chosen by the caller.
5. Prove registration, password sign-in/recovery, email/SMS OTP where admitted, native Google OAuth cancellation, refresh, restart, logout and A→B account switch. Test wrong issuer/audience, expired/forged token, key rotation/outage, deleted/blocked account, old-device session, mapping collision and duplicate bootstrap.
6. Verify existing learning progress, notebook/journal namespaces, claims, shop receipts, pending events and deletion acknowledgements remain attached to the same app user. No client-supplied entitlement or profile ID can cross the boundary.
7. Roll back provider selection without deleting learner data or assigning fresh IDs. Revoke sessions and purge account-local state under the chosen provider's documented semantics; an Appwrite bridge requires both lifecycles to be reconciled.

## Consequences

Custom Flutter UI is compatible with the provider's APIs, but console configuration, password policy, OAuth/deep links, secure storage and actual device/network acceptance are still required. Account quotas, SMS/email delivery charges, Pro expiry and downgrade/export handling require account evidence before production; no entitlement is inferred from a screenshot alone.

Affected owners on selection: root identity rule, AUTH, OpenAPI security descriptions if applicable, DATA_MODEL/migrations, PERMISSIONS, Flutter config/repositories, backend AuthPort/composition, deletion lifecycle, CI secrets and real-profile acceptance. [ADR-0018](0018-container-event-cache-runtime.md) remains accepted independently of this provider decision.
