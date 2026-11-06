# VPS HTTPS routing template

Prepared only: no Nginx installation, syntax check, certificate request, reload or live request has been performed. This is host routing for the existing three services; it introduces no new application gateway/API or business authorization.

Replace the three `*-staging.example.invalid` domains in the site configuration and common service env file. Point DNS at the VPS, provision trusted certificates through the host's chosen certificate manager and update the certificate paths. The sample paths describe an already-provisioned certificate layout; no certificate issuance or renewal automation is included.

The site file belongs in the Nginx `http` context. Put the two snippets at the `/etc/nginx/snippets/` paths referenced in that file. Review the VPS's existing sites/default server, IPv6 listeners, TLS policy, certificate renewal and log rotation before enabling it; do not overwrite another site's configuration.

HTTPS routes forward to the three loopback ports from Compose. `proxy_pass` has no URI suffix, and there are no rewrite directives, so the original request URI is preserved as described by the [Nginx proxy documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass). This is required for the current HMAC path/query contract and still needs real proxy verification. Do not add a trailing slash to the upstream URLs or rewrite internal paths. Headers carrying JWT/HMAC are forwarded; the .NET service continues to authenticate and authorize every protected request.

`/internal/` and exact `/ready` use the shared allowlist. It initially permits loopback only and denies everything else. Add the actual source addresses/CIDRs used by the three services and authorized operators before running inter-service delivery. Determine the real source after Docker/NAT/VPS routing; do not assume a bridge CIDR or add broad private networks. Nginx processes allow/deny rules in order, so trusted entries must precede `deny all`; see the [access module](https://nginx.org/en/docs/http/ngx_http_access_module.html). Network permission does not replace valid HMAC signatures. Keep those endpoints closed to public callers.

For API calls, configure HTTPS URLs directly instead of relying on HTTP redirects. The HTTP virtual hosts only redirect to their fixed configured HTTPS domains. A separate existing/default host policy must handle unrecognized Host/SNI values. Container ports remain bound to loopback.

The 1 MiB proxy body ceiling is above the application's current 750,000-byte voice-body ceiling. The 180-second upstream timeouts are initial staging settings for provider fallback/polling; tune them after observing the real host. Automatic upstream retries and proxy error interception are disabled so application responses pass through and retry ownership remains with the existing client/outbox protocol. Proxy-generated failures such as 413/502/504 still require client/error-handling review.

The supplied access log uses status, timings, configured host and the response request ID, without raw URI/query, body, authorization or HMAC headers. Review other Nginx/server logs and any upstream CDN/load balancer: these snippets do not control host-wide logging. They do not configure an exporter or a dashboard.

Before admission, perform the deferred checks for DNS/certificates, source allowlists, signed paths/query strings, auth headers, body/error handling, cancellation, timeout and log redaction in [pending verification](../../../../migration/VERIFICATION_PENDING.md). None of these checks has been marked complete.
