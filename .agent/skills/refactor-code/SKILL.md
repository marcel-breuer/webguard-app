# Skill: Refactor Code

## Purpose

Improve internal structure while preserving WebGuard iOS behavior.

## When to Use

Use for explicit refactoring, simplification, duplication removal, or maintainability tasks.

## When Not to Use

Do not use when behavior changes are required unless paired with the appropriate feature or bug skill.

## Required Context

Read root `AGENTS.md`, the exact code being refactored, nearby patterns, and any affected validation documentation.

## Relevant Project Areas

Affected files under `ios/WebGuard/App` and the Xcode project only if files are added, moved, or removed.

## Procedure

1. State the intended behavior-preserving boundary.
2. Keep public behavior, API contracts, storage keys, entitlements, and privacy behavior unchanged.
3. Move code only when ownership becomes clearer under existing architecture rules.
4. Avoid formatting churn outside touched code.
5. Add tests if feasible for behavior that could regress.

## Validation

Run the documented `xcodebuild` build and any relevant tests if present.

## Expected Output

Report what structure changed, why it is behavior-preserving, changed files, and validation.

## Constraints

Do not introduce speculative abstractions, dependency changes, or unrelated UI redesign.

## Completion Criteria

The refactor is behavior-preserving, focused, and validated or blockers are disclosed.
