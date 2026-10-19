# iOS validation

The iOS project uses the existing `WebGuardTests` XCTest target. Tests use local JSON fixtures and injected in-memory session/cache/API stores; they do not require a WebGuard account, a live API, or APNs.

## Local commands

Build without signing:

```sh
xcodebuild \
  -project ios/WebGuard.xcodeproj \
  -scheme WebGuard \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the deterministic simulator suite:

```sh
xcodebuild \
  -project ios/WebGuard.xcodeproj \
  -scheme WebGuard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The suite covers the healthy, down, unknown, maintenance, empty, offline, error, unauthorized, cached, notification, device, monitoring-detail, and deep-link states. The app exposes stable accessibility identifiers for the overview, service rows, attention actions, monitoring rows/details, notification rows, settings controls, and push preference controls.

The reliability checks also verify that API credentials stay in the bearer header, requests use the configured HTTPS and timeout budgets, Keychain sessions are device-only, parallel sign-in requests remain concurrent, and overlapping monitoring refreshes issue only one request.

## Performance measurements

The unit suite includes `testLocalCacheLoadPerformanceAtMonitoringCapacity`, which measures cache decoding with 100 synthetic monitors. For cold launch, actual SwiftUI row rendering, and network refresh, use Instruments on a device with the same 100-monitor workload. The app emits Points of Interest intervals named `AppStateInitialization`, `MonitoringListFiltering`, and `MonitoringRefresh`; record the device, OS, cache state, and network with each run. See [the architecture notes](../docs/ios-architecture.md#performance-measurement) for the current budgets and profiling setup.

## Manual checks

The current project has no authenticated UI-test fixture or APNs simulator harness. Before release, manually verify the authenticated shell on iPhone portrait and iPad portrait/landscape, including Dynamic Type, VoiceOver traversal, reduced motion, offline refresh, maintenance, and push deep-link flows.
