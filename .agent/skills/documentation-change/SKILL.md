# Skill: Documentation Change

## Purpose

Keep WebGuard repository documentation accurate, concise, and consistent with implementation.

## When to Use

Use for README, App Store docs, setup instructions, validation commands, API documentation, privacy notes, or governance changes.

## When Not to Use

Do not use for app code changes unless documentation also changes.

## Required Context

Read root `AGENTS.md`, the docs being changed, and the implementation or configuration that supports the documented facts.

## Relevant Project Areas

`README.md`, `docs/ios-app-store.md`, `AGENTS.md`, `.agent/skills/`, and thin adapter files.

## Procedure

1. Document only verified repository behavior.
2. Keep setup, validation, environment, API, privacy, and release instructions aligned with code/configuration.
3. Avoid duplicating canonical governance rules in adapters or skills.
4. Do not include secrets, private accounts, or production personal data.
5. Keep output concise and remove stale statements when replacing them.

## Validation

Review Markdown for accuracy, links, command existence, and absence of conflicting instructions. Run code validation only if code/configuration changes require it.

## Expected Output

Report changed documents, validation performed, and any assumptions.

## Constraints

Do not edit unrelated docs or generated documentation.

## Completion Criteria

Documentation is accurate, scoped, non-duplicative, and supported by repository evidence.
