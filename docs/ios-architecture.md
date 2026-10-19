# iOS Architecture and Reliability

This page records the current API, state, persistence, refresh, and security boundaries for the native app. The source remains authoritative when an implementation detail changes.

## App boundaries

| Area | Owner | Responsibility |
| --- | --- | --- |
| SwiftUI screens | `ios/WebGuard/App/*View.swift` | Render state and send user actions to `AppState` |
| Session and workflows | `AppState.swift` | Coordinate authentication, monitoring refresh, push events, cached state, and user-visible failures |
| HTTP transport | `WebGuardAPIClient.swift` | Build HTTPS requests, attach bearer authorization, decode responses, and map HTTP errors |
| API models | `Models.swift` | Codable request and response models |
| Session persistence | `KeychainStore.swift` | Store the signed-in session in the iOS Keychain |
| Non-secret cache | `LocalCache.swift` | Store account-scoped monitor, event, overview, preference, and detail data in `UserDefaults` |
| Push handling | `APNsService.swift`, `WebGuardApp.swift` | Request notification permission, register APNs, and convert validated payloads into app events |

`AppState` accepts session, cache, push, device-context, and API-client dependencies. `WebGuardAPIClient` accepts a `URLSession`; the XCTest target uses these seams and a local `URLProtocol` stub instead of live services.

## WebGuard API contract

The app reads its base URL from `WEBGUARD_BASE_URL`. Mobile resources use `/api/mobile`; platform resources such as monitorings and teams use `/api`. Authenticated calls send the session token only in the `Authorization: Bearer` header. JSON dates use ISO 8601.

| Method | Path |
| --- | --- |
| `POST` | `/api/mobile/login` |
| `POST` | `/api/mobile/logout` |
| `GET` | `/api/monitorings` |
| `POST`, `PATCH`, `DELETE` | `/api/monitorings`, `/api/monitorings/{id}` |
| `GET` | `/api/monitorings/{id}/status` |
| `GET` | `/api/mobile/monitorings/{id}?days={1..90}&incident_limit=20&incident_offset={offset}` |
| `GET`, `PATCH` | `/api/mobile/monitorings/{id}/notification-preferences` |
| `GET` | `/api/mobile/overview?service_page={page}` |
| `GET` | `/api/mobile/monitoring-groups?per_page=100` |
| `POST`, `PATCH`, `DELETE` | `/api/mobile/monitoring-groups` and `/api/mobile/monitoring-groups/{id}` |
| `GET` | `/api/teams` |
| `POST` | `/api/monitorings/{id}/ownership/team` and `/api/monitorings/{id}/ownership/private` |
| `GET` | `/api/mobile/maintenance/{kind}?per_page=100[&state={state}]` |
| `GET`, `POST` | `/api/mobile/maintenance/capabilities`, `/api/mobile/maintenance` |
| `PATCH`, `DELETE` | `/api/mobile/maintenance/recurring/{id}`, `/api/mobile/maintenance/one-off/{monitoringId}` |
| `POST`, `PATCH`, `DELETE` | `/api/mobile/push-devices` and `/api/mobile/push-devices/{id}` |
| `GET` | `/api/mobile/notification-board?limit=50&show_read={bool}[&cursor={cursor}][&event_type={type}]` |
| `PATCH` | `/api/mobile/notification-board/{id}/read`, `/api/mobile/notification-board/read-all` |
| `GET` | `/api/mobile/status-pages?per_page=100` |
| `GET` | `/api/mobile/status-pages/{id}/incidents?state=open&per_page=100` |
| `GET` | `/api/mobile/status-pages/{id}/incidents/{incidentId}` |
| `PATCH` | `/api/mobile/status-pages/{id}/publication` |
| `PATCH` | `/api/mobile/status-pages/{id}/incidents/{incidentId}/metadata` and `/review` |
| `POST` | `/api/mobile/status-pages/{id}/incidents/{incidentId}/updates`, `/follow-ups`, and `/timeline` |
| `PATCH`, `DELETE` | `/api/mobile/status-pages/{id}/incidents/{incidentId}/follow-ups/{followUpId}` and `/timeline/{eventId}` |

Incident update, follow-up, and timeline creation requests include an `Idempotency-Key`. A `204` response is accepted only for calls that expect no response body. HTTP `401` and `403` are treated as an expired or unauthorized session; other HTTP failures use localized messages that do not expose response bodies.

## Refresh and offline behavior

| Budget | Current value | Behavior |
| --- | --- | --- |
| API request timeout | 15 seconds | Each `URLSession` request has a bounded timeout; no automatic retry is performed |
| Monitoring freshness | 5 minutes | Data older than this is labeled stale and is refreshed when the monitoring list opens; pull-to-refresh remains available |
| Notification-board freshness | 5 minutes | The board can refresh when it is stale |
| Overlapping monitoring refreshes | 1 request | A second list refresh returns while the active request updates shared state |
| Cached monitors / push events / monitor details | 100 / 50 / 20 | Older entries are discarded when these caches are saved |

The first sign-in performs the required monitoring-list request and optional overview request concurrently. If the overview request fails, the app builds a local fallback from monitorings and events. If monitorings cannot be loaded, sign-in fails without saving the session.

There is no periodic `BGAppRefreshTask`. The app refreshes the list when it is empty or stale on screen entry and when the user pulls to refresh. APNs delivers monitoring events while the app is suspended when iOS permits remote-notification delivery. On a network failure, cached data stays visible with an offline or stale state and a retry action. A `401` or `403` clears the session and its account cache.

## Persistence and privacy

- The complete `StoredSession`, including the access token, is serialized to the Keychain under the `session` account. Items use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Monitorings, events, overview data, notification preferences, notification-board entries, refresh timestamps, and monitoring details use an account-scoped, versioned `UserDefaults` namespace. They are not a token store.
- The cache currently keeps at most 100 monitorings, 50 push events, and 20 monitoring details. Sign-out clears the active account cache and the widget snapshot.
- The app does not add analytics or diagnostic logging. Push payloads require `monitoring_id` and `monitoring_name`; optional event fields are parsed defensively. Payload values that become local event data must be appropriate for display and local storage on the signed-in device.
- The app accepts only HTTPS server and registration URLs with a host and without URL credentials. `Info.plist` has no App Transport Security exception. The `webguard://monitoring/{id}` deep link parser accepts only the known scheme and destination.

## Performance measurement

Monitor rows are rendered in a `LazyVStack`. The app emits Points of Interest intervals for `AppStateInitialization`, `MonitoringListFiltering`, and `MonitoringRefresh`. The XCTest target also measures decoding the cached list at its supported capacity of 100 monitors.

For a device-specific profile, run the app with a 100-monitor test account and record cold launch, first list presentation, scroll rendering, and a pull-to-refresh in Instruments. Use the App Launch, SwiftUI, and Points of Interest instruments. Record device model, iOS version, cache state, network, and the observed intervals with each result; do not compare measurements from different device or network conditions as if they were the same workload. The repository sets request and freshness budgets, but does not set a launch- or frame-time SLA because no reference device target is defined.
