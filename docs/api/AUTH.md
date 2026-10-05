# Authentication and route authorization

Flutter uses Appwrite Account SDK for create, createEmailPasswordSession, createOAuth2Session, get, createJWT, deleteSession(current), verification/recovery and OAuth identity flow. These managed endpoints are not relabeled business-service APIs. [Appwrite JWT documentation](https://appwrite.io/docs/products/auth/jwt) states15-minute lifetime or expiry on session deletion.

SDK session persistence remains within official client behavior; tokens returned for business access remain in memory. Do not persist an Appwrite JWT in SharedPreferences. Secure storage holds only app-owned sensitive cache-encryption material where required; no admin/provider key. P3 verifies actual SDK Android/iOS session restoration and logout; do not assume a particular cookie implementation without tests.

For each business REST call: obtain/refresh a short-lived Appwrite JWT from the valid SDK session (single-flight refresh, refresh before expiry); send Authorization: Bearer jwt over HTTPS. Service creates a per-request Appwrite JWT client and calls Account.get; never trust decode-only JWT/user-id header. Fail closed on Account failure. Direct Function example headers in docs use x-appwrite-user-jwt; the service may normalize that transport header but still verifies Account.get. Do not log either credential.

Every operation other than /health requires a verified subject or explicitly defined internal HMAC. /ready is maintainer/internal-only in hosted mode. Owner rows use subject from Account.get, not body userId. Team membership for content publication is server-authoritative. User API key/admin console identity is not a learner session.

Guest course list/intro reads the bundled public manifest or public immutable Storage content; it does not call protected listCourses. After login the repository switches to authoritative API listing and enrollment. Local cache-only routes never dispatch pending protected mutations until a verified online session returns.

Boot route guards: restoring→only boot; signedOut→welcome/auth/guest; verified without enrollment→onboarding; verified enrolled→home; cacheOnly→offline practice/read-only path. Protected deep link preserved once; failure never loops between login/home. Deleted/blocked accounts never reinitialize their profile.

OAuth: Google configured per Appwrite platform/package/bundle and redirect scheme; Appwrite manages exchange. Apple enabled only with real eligible provider configuration for iOS; email/password remains usable for unsigned simulator demo. User links a provider while logged into the owning account using documented SDK flow; duplicate provider identity produces explicit help, not cross-account data merge. Provider refresh token is never a Flutter business token.

Registration policy password≥12 project characters; server Auth enforces available policy. Verification screen sends generic confirmation; social opt-in requires verified email/OAuth status. Recovery uses Appwrite-issued links and scheme allowlist; user-entered redirect URL forbidden. Auth SDK rate limits remain authoritative; app applies UI cooldown and generic messages.

Logout offline removes local ability to act immediately; it cannot promise remote revocation without connectivity. Online session deletion and account blocked state ensure JWT rejection. Account deletion API accepts request, blocks/revokes, distributes purge, acknowledges completion only when all owners have removed private data; tombstone retained long enough to stop stale replay.
