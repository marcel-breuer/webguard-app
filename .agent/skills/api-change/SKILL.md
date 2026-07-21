# Skill: API Change

## Purpose

Change WebGuard API request, response, authentication, or error-handling behavior safely.

## When to Use

Use for endpoint changes, payload or DTO changes, status handling, auth headers, timeout behavior, and API-driven app flows.

## When Not to Use

Do not use for UI-only changes or unrelated persistence changes.

## Required Context

Read root `AGENTS.md`, `WebGuardAPIClient`, relevant models, affected `AppState` flows, README endpoint documentation, and backend contract information supplied by the task.

## Relevant Project Areas

`ios/WebGuard/App/WebGuardAPIClient.swift`, `ios/WebGuard/App/Models.swift`, `ios/WebGuard/App/AppState.swift`, `README.md`, and release docs when user-visible behavior changes.

## Procedure

1. Confirm the intended endpoint prefix, method, auth requirement, payload, and response shape.
2. Keep JSON encoding/decoding typed with `Codable`.
3. Preserve bearer token handling and unauthorized behavior unless explicitly changed.
4. Avoid exposing raw sensitive response data in user-facing errors or logs.
5. Update docs if documented endpoints or smoke tests change.

## Validation

Run the documented `xcodebuild` build. Use live API smoke tests only with approved non-production accounts and no secret logging.

## Expected Output

Report API behavior changed, affected files, validation, and any unverified backend contract assumptions.

## Constraints

Do not invent backend behavior, endpoints, fields, or business requirements.

## Completion Criteria

The API change matches the supplied contract, compiles, and preserves security and privacy expectations.
