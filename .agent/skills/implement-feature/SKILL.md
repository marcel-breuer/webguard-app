# Skill: Implement Feature

## Purpose

Add focused WebGuard iOS functionality while preserving architecture, security, and reviewability.

## When to Use

Use for new app behavior, new screens, new user flows, or workflow changes.

## When Not to Use

Do not use for pure bug fixes, documentation-only edits, dependency-only changes, or code review.

## Required Context

Read the task, root `AGENTS.md`, relevant Swift files, relevant README sections, and any API or App Store documentation affected by the feature.

## Relevant Project Areas

`ios/WebGuard/App`, `ios/WebGuard/Config`, `ios/WebGuard/Info.plist`, `ios/WebGuard/WebGuard.entitlements`, `ios/WebGuard/PrivacyInfo.xcprivacy`, `README.md`, and `docs/ios-app-store.md`.

## Procedure

1. Identify the smallest behavior change that satisfies the task.
2. Place API work in `WebGuardAPIClient`, state workflow in `AppState`, secure persistence in `KeychainStore`, local cache work in `LocalCache`, APNs work in `APNsService`, and UI work in SwiftUI views.
3. Reuse existing models, `Brand` styling, async patterns, and error handling.
4. Add or update tests if feasible; if test infrastructure is required, keep it scoped.
5. Update docs only for changed setup, API, privacy, or user-visible behavior.

## Validation

Run the documented `xcodebuild` build when app files change. Add focused manual validation notes for APNs, login, or live API behavior that cannot be automated.

## Expected Output

Report changed behavior, changed files, validation results, and any untested manual flows.

## Constraints

Do not add third-party SDKs, telemetry, new external services, secrets, or unrelated refactors without explicit approval.

## Completion Criteria

The feature is implemented through the established architecture, validates successfully or has disclosed blockers, and does not introduce unrelated changes.
