# Skill: Update Dependencies

## Purpose

Evaluate and manage dependency changes for the WebGuard iOS app.

## When to Use

Use when adding a package manager, adding a third-party library, or changing dependency configuration.

## When Not to Use

Do not use for changes limited to Apple frameworks already available in the SDK.

## Required Context

Read root `AGENTS.md`, Xcode project settings, relevant app code, README, and the proposed dependency documentation or license.

## Relevant Project Areas

`ios/WebGuard.xcodeproj`, any newly introduced package or lockfile, README, privacy manifest, and code using the dependency.

## Procedure

1. Confirm the repository currently has no package manager or third-party dependency manifest.
2. Justify why Apple frameworks or existing code are insufficient.
3. Review license, maintenance, security posture, binary size, privacy behavior, App Store impact, and duplicate functionality.
4. Add only the minimum required dependency and commit corresponding lock/configuration files.
5. Update documentation and privacy disclosures if behavior changes.

## Validation

Run a clean dependency resolution command if one is introduced, then run the documented `xcodebuild` build.

## Expected Output

Report dependency rationale, files changed, validation, and licensing/privacy risks.

## Constraints

Do not add analytics, tracking, paid SDKs, or unrequested major ecosystem changes without explicit approval.

## Completion Criteria

The dependency change is justified, minimal, documented, validated, and privacy-safe.
