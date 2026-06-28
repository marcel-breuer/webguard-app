# Skill: Write Tests

## Purpose

Add practical regression or behavior coverage for WebGuard iOS code.

## When to Use

Use when the task asks for tests or a change affects business logic, API handling, persistence, parsing, or state transitions.

## When Not to Use

Do not use for documentation-only changes or trivial visual-only changes where tests would add no meaningful signal.

## Required Context

Read root `AGENTS.md`, changed code, the Xcode project configuration, and any existing or proposed test target files.

## Relevant Project Areas

`ios/WebGuard.xcodeproj`, `ios/WebGuard/App`, and any new scoped test target or fixtures.

## Procedure

1. Verify whether a test target exists; this checkout currently has none.
2. Prefer testing pure logic, model decoding, URL construction, cache behavior, and state transitions with injected dependencies.
3. Avoid live WebGuard API, APNs, production data, and real secrets in tests.
4. Keep fixtures minimal and non-sensitive.
5. Document any newly introduced test command in `AGENTS.md` or relevant docs.

## Validation

Run the new test command if test infrastructure is added, plus the documented `xcodebuild` build for app changes.

## Expected Output

Report the behavior covered, files changed, command run, and any coverage gaps.

## Constraints

Do not add broad test infrastructure or snapshot files unless justified by the changed behavior.

## Completion Criteria

Tests are deterministic, scoped to observable behavior, and validated or blockers are disclosed.
