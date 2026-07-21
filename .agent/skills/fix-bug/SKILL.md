# Skill: Fix Bug

## Purpose

Diagnose and correct incorrect WebGuard iOS behavior with minimal, testable changes.

## When to Use

Use for crashes, regressions, broken API flows, UI defects, APNs issues, persistence errors, or incorrect state transitions.

## When Not to Use

Do not use for new feature work, broad refactoring, dependency updates, or documentation-only tasks.

## Required Context

Read the bug report, root `AGENTS.md`, the smallest relevant code path, and any related docs or configuration.

## Relevant Project Areas

`AppState`, `WebGuardAPIClient`, `APNsService`, `KeychainStore`, `LocalCache`, affected SwiftUI views, build config, entitlements, and privacy manifest when relevant.

## Procedure

1. Reproduce or reason from the narrow failing path.
2. Identify the owner of the faulty behavior by architecture boundary.
3. Make the smallest correction and avoid speculative cleanup.
4. Add a regression test if feasible; otherwise document why not.
5. Check for security or privacy side effects.

## Validation

Run the documented `xcodebuild` build for code changes and any focused manual validation matching the fixed flow.

## Expected Output

Report root cause, fix summary, changed files, validation, and remaining risk.

## Constraints

Do not weaken error handling, auth handling, APNs permission behavior, Keychain storage, or privacy controls to fix a symptom.

## Completion Criteria

The reported behavior is corrected, validation is complete or blockers are disclosed, and the diff is focused.
