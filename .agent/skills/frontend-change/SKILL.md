# Skill: Frontend Change

## Purpose

Update the native SwiftUI user experience consistently with WebGuard app patterns.

## When to Use

Use for SwiftUI screens, navigation, forms, loading, empty, error states, responsive layout, or accessibility changes.

## When Not to Use

Do not use for API-only, persistence-only, documentation-only, or dependency-only tasks.

## Required Context

Read root `AGENTS.md`, affected views, `Brand.swift`, `RootView.swift` or tab structure when relevant, and any user-facing docs affected by the change.

## Relevant Project Areas

`ConnectView`, `PushSetupView`, `MonitoringListView`, `NotificationsView`, `SettingsView`, `RootView`, `Brand`, and related state in `AppState`.

## Procedure

1. Reuse existing visual tokens, card helpers, fonts, spacing style, and SF Symbols.
2. Keep side effects in `AppState` or services rather than view bodies.
3. Preserve iPhone and iPad usability, including iPad landscape.
4. Include clear loading, empty, disabled, and error behavior where the flow needs it.
5. Keep German UI copy consistent unless explicitly changed.

## Validation

Run the documented `xcodebuild` build. For visual changes, inspect in Xcode previews or simulator/device when available and report if not performed.

## Expected Output

Report UI behavior changed, changed files, validation, and any unverified device or orientation coverage.

## Constraints

Do not add web frontend tooling, marketing pages, analytics, or third-party UI SDKs without explicit approval.

## Completion Criteria

The UI change is consistent, accessible enough for the scope, validated, and free of unrelated redesign.
