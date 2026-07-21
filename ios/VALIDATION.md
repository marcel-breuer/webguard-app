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

## Manual checks

The current project has no authenticated UI-test fixture or APNs simulator harness. Before release, manually verify the authenticated shell on iPhone portrait and iPad portrait/landscape, including Dynamic Type, VoiceOver traversal, reduced motion, offline refresh, maintenance, and push deep-link flows.
