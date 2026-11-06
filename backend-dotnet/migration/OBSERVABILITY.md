# Observability implementation notes

Status: request and outbox instrumentation is implemented in the shared host/job runners, not built or tested under the current implementation-only instruction. Hosting collection, dashboards and alerts remain to be configured. See [pending verification](VERIFICATION_PENDING.md) and the existing [operations owner](../../docs/devops/OPERATIONS.md).

## Request completion log

`RequestTelemetryMiddleware` runs after routing and wraps the API boundary. JSON console logs contain event ID `1001` (`ApiRequestCompleted`) with these structured fields:

| Field | Value |
| --- | --- |
| Service / BuildId | Runtime service name and configured build ID |
| Operation / Route | Known operation ID and route template; unknown routes use `unmatched` |
| Method | Supported HTTP method or `OTHER` |
| StatusCode | Response status; telemetry-only 499 for client cancellation, 500 for an uncaught exception |
| ElapsedMs | Monotonic elapsed time |
| RequestId | API-boundary request ID; server trace identifier if absent |
| ErrorCode | Bounded API error code or `none`; abort/unhandled cases have fixed telemetry codes |
| Aborted | Whether request cancellation propagated from the client |

The middleware does not serialize bodies, query strings, request headers, route parameter values, identity objects, error details or exceptions. API boundary failures supply only their catalog error code. Information-level ASP.NET Hosting diagnostics and HttpClient diagnostics are filtered because their request messages include raw URLs. Review the full hosting log pipeline when enabling other categories or providers.

Log severity follows the recorded status: Information for status below 400, Warning for 4xx and Error for 5xx. The telemetry-only status never changes the actual response or suppresses cancellation/uncaught exceptions. Known model-binding/other responses without an API-boundary exception may have `ErrorCode=none`; status and operation remain available.

## Built-in meter

Meter `CocEnglish.Api` exposes `cocenglish.api.requests` (counter, requests) and `cocenglish.api.request.duration` (histogram, milliseconds). Tags are service, operation, method, status code and error code. Request IDs, user IDs, URLs and build IDs are excluded from metric tags.

Metrics can be exported over OTLP/HTTP when `COC_OTEL_METRICS_ENDPOINT` is explicitly set to a full `.../v1/metrics` URL. The shared host exports only `CocEnglish.Api` and `CocEnglish.Workers` meters, using the service name as the resource identity. Exporting is disabled when the endpoint is blank; no logs or traces are exported. The optional `compose.staging.otel-secrets.yaml` overlay mounts per-service `COC_OTEL_METRICS_HEADERS` files without placing credentials in container environment variables. The hosting operator must provide a trusted collector endpoint, TLS or a private container network, retention, dashboards and alerts. No collector service or public metrics scrape endpoint is added here.

## Worker and outbox metrics

Meter `CocEnglish.Workers` exposes `cocenglish.worker.ticks` (counter, ticks), `cocenglish.worker.tick.duration` (histogram, milliseconds) and `cocenglish.outbox.events` (counter, events). The tick tags are service, worker and outcome (`success`, `failure` or `cancelled`). Worker values are fixed: Progress `outbox_relay`, `deletion_purge`, `streak_rollover`, `league_settlement`; Learning and AI `outbox_dispatch`. Outbox tags are service and outcome (`leased`, `acked`, `retried` or `dead`). Values are fixed by the service runners; no user, event, request or owner ID is attached.

The shared Learning, Progress and AI job runners record both signed job-route and scheduled-worker invocations. All four Progress jobs are measured, as are Learning/AI outbox dispatches. `leased` is the total claimed for that tick; the other outcomes are its ACK/retry/dead counts. The event counter records zero-valued outcomes too, so a collector can establish the bounded outcome series. These metrics complement the existing structured worker logs; they do not include payloads or exception text.

`cocenglish.outbox.backlog` is an observable gauge with service/state tags (`pending`, `leased`, `dead`). `cocenglish.outbox.oldest_event.age` reports the age in milliseconds of the oldest PENDING or LEASED event, tagged only by service; it is omitted when no active event exists. A separate background sampler performs three owner-scoped `CountAsync` queries and one owner-scoped, one-row query once per minute, only when the OTLP endpoint is configured and that service's Appwrite host admission is enabled. The age query selects only `occurredAt` as application data, uses the `(status,occurredAt)` index, and does not read event payloads. The sampler discards any row ID returned by the adapter; no row ID is logged or exported. Both samples clear after a failed refresh rather than presenting stale values. The cutover runbook still requires dashboard/alert configuration and durable recovery evidence.

## Correlation and remaining work

Use RequestId and BuildId from request completion logs to locate a failed call, then correlate with aggregate worker metrics, existing worker tick logs and safely stored event evidence. Detailed event-level diagnosis must use the redacted logs and storage controls; metric tags remain bounded. Outbox age/depth/DEAD dashboards and durable recovery evidence are still required by the cutover runbook; counters do not replace them.

Verify all request and worker success/error/cancellation paths, outbox counter semantics, log redaction, metric tags, exporter-disabled behavior and OTLP delivery/collector rejection before accepting this part of the deployment. These checks have been deferred, not completed.
