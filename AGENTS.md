# AGENTS.md

These instructions apply to every human or AI coding agent working in this repository, regardless of the tool, model, IDE, extension, CLI, automation platform, or execution environment.

This file is the canonical source of project-wide instructions. Adapter files for specific tools MUST stay thin and MUST reference this file, any nearer local `AGENTS.md`, and `.agent/skills/` without duplicating or contradicting the complete rule set.

## Scope and Applicability

- These rules apply to all repository changes by humans and coding agents.
- Local `AGENTS.md` files MAY add directory-specific rules. The nearest applicable `AGENTS.md` takes precedence for local implementation details.
- Local rules MUST NOT weaken security, privacy, compliance, or reviewability requirements from this file.
- Agent-specific adapters MUST NOT create different standards for different tools.
- Shared skills in `.agent/skills/` supplement this file and never override it.
- Tools without a repository-specific adapter, including OpenCode, Windsurf, Cline, Roo Code, Aider, and comparable agents, are governed directly by this file and `.agent/skills/`.

## Instruction Priority

Apply instructions in this order:

1. Explicit task requirements and acceptance criteria.
2. Security, privacy, legal, and compliance requirements.
3. Nearest applicable local `AGENTS.md`.
4. Root `AGENTS.md`.
5. Existing architecture and established repository patterns.
6. Repository configuration.
7. Tests and technical documentation.
8. Official language and framework documentation.
9. Established community standards.
10. Explicitly documented assumptions.

Agents MUST NOT invent business requirements.

## Project Overview

- WebGuard for iOS is a native iPhone and iPad app for WebGuard monitoring alerts.
- The app is Swift 5 using SwiftUI, UIKit integration, UserNotifications, Security framework Keychain access, URLSession, and UserDefaults.
- The app target is `WebGuard` in `ios/WebGuard.xcodeproj`; source lives under `ios/WebGuard/App`.
- `WebGuardApp.swift` is the SwiftUI entry point, with `AppDelegate` handling APNs registration and notification callbacks.
- `AppState` coordinates session state, monitorings, push events, Keychain persistence, local cache, APNs setup, and API calls.
- `WebGuardAPIClient` owns WebGuard HTTP API requests. Models and DTOs live in `Models.swift`.
- Non-secret build values live in `ios/WebGuard/Config/Debug.xcconfig` and `ios/WebGuard/Config/Release.xcconfig`.
- APNs entitlement and privacy manifest files are included in `ios/WebGuard`.
- There is no Docker, package manager, lockfile, test target, database, CI/CD, or infrastructure-as-code configuration in this checkout.
- If project Docker or container configuration is added later, agents MUST prefer the project-defined container workflow for installs, commands, tests, and validation when technically possible.

## Source of Truth

Technical decisions MUST follow this priority:

1. Existing implementation and established patterns.
2. Project configuration.
3. Tests, when present.
4. Repository documentation.
5. Official Apple, Swift, and SwiftUI documentation.
6. Established Swift and iOS standards.

Agents MUST NOT replace existing conventions with personal preferences without a concrete technical reason.

## Token Efficiency

- Read only files relevant to the current task.
- Do not scan the full repository when targeted inspection is sufficient.
- Prefer precise searches over broad file reads.
- Avoid repeatedly reading unchanged files.
- Do not restate the complete task before starting.
- Do not repeat rules already defined in this file.
- Do not include long implementation plans unless task complexity requires them.
- Keep plans concise and focused on execution-critical steps.
- Do not narrate routine tool usage.
- Report only findings that affect implementation, validation, risk, or review.
- Prefer diffs and targeted edits over rewriting complete files.
- Avoid creating abstractions, documentation, comments, tests, or files that are not required.
- Do not produce large code excerpts in final output when file references are sufficient.
- Do not duplicate the same information across summaries, findings, and completion reports.
- Use concise tables or short lists where they reduce repetition.
- Token efficiency MUST NOT justify skipping required analysis, validation, correctness, or security work.

Final output SHOULD normally include only what changed, files changed, validations executed, and unresolved issues, assumptions, or risks.

## Swift and iOS Standards

- Follow Swift API Design Guidelines and existing project style: `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, clear domain names for DTOs, views, services, and helpers.
- Keep SwiftUI views as `struct View` types and shared visual helpers in small modifiers or components consistent with `Brand.swift`.
- Keep app-wide mutable UI state on the main actor where it drives SwiftUI updates.
- Use `async`/`await` for asynchronous API, APNs, and state workflows.
- Use `Codable` models and repository-established ISO 8601 JSON date strategies for API and local persistence.
- Use typed `Error` or `LocalizedError` values for user-facing failures where practical.
- Keep public interfaces explicitly typed. Avoid force unwraps except for static constants that are guaranteed by construction and already follow project convention.
- UI text currently uses German strings in app screens. Preserve that convention unless the task explicitly changes localization.
- Use SF Symbols and existing `Brand` colors/helpers for SwiftUI UI changes.

## Architecture Rules

- Keep WebGuard API transport and request/response handling in `WebGuardAPIClient`.
- Keep session, monitor list, push event, and workflow coordination in `AppState`.
- Keep secure session persistence in `KeychainStore`; do not store access tokens in UserDefaults.
- Keep local non-secret monitor and event caching in `LocalCache`.
- Keep APNs authorization, token receipt, and push event conversion in `APNsService` and `AppDelegate`.
- Keep DTOs and simple domain models in `Models.swift` unless the file becomes too large for focused review.
- SwiftUI views SHOULD delegate side effects to `AppState` or focused services rather than embedding network or persistence logic directly.
- External integrations are limited to WebGuard HTTP APIs, APNs, Keychain, UserDefaults, and Apple system frameworks unless explicitly approved.
- New abstractions require a concrete benefit: reduced duplication, clearer boundaries, testability, or alignment with existing patterns.

## Code Quality

- Keep functions and views focused; split only when it improves readability or reuse.
- Remove unused imports, variables, dead code, and commented-out code.
- Use meaningful constants for repeated or non-obvious values.
- Comments SHOULD explain why, not restate what the code does.
- Do not introduce broad disable comments, unchecked casts, or unsafe shortcuts to bypass compiler checks.
- Do not make unintended public API, entitlement, privacy, or user-facing behavior changes.
- Identify breaking changes explicitly.
- Do not weaken existing quality checks or build settings.

## Naming Conventions

- Swift files SHOULD contain the primary type named by the file when practical.
- View types end with `View` for screens or reusable view components.
- Service and persistence types use descriptive suffixes such as `Service`, `Client`, `Store`, or `Cache`.
- API payload and response types should name the WebGuard concept and direction, such as `MobileLoginPayload` or `MobilePushDeviceResponse`.
- Configuration keys, API field names, and entitlement values MUST match backend or Apple requirements exactly.
- Branch names, commit messages, comments, documentation, and PR text MUST NOT mention coding-agent or automation-tool branding unless explicitly required.

## Testing Rules

- No test target or test framework exists in this checkout.
- Add tests for new or changed business logic when feasible. If adding a test target, keep it scoped to the changed behavior and document the new validation command.
- Bug fixes SHOULD include regression tests where practical.
- Tests MUST verify observable behavior rather than implementation details.
- Tests MUST be deterministic, isolated from live WebGuard APIs and APNs unless explicitly designated as manual smoke tests, and must not use production personal data or secrets.
- Do not remove, skip, or weaken tests merely to make changes pass.

## Validation Commands

Prefer project-defined commands. This checkout has no Docker or container configuration; use Xcode tooling directly when validation is required. If container configuration is added later, prefer the project-defined container workflow when technically possible.

| Change type | Required validation |
| --- | --- |
| Swift app logic or UI | `xcodebuild -project ios/WebGuard.xcodeproj -scheme WebGuard -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` |
| Project, entitlement, privacy, or asset changes | Same `xcodebuild` build, plus focused inspection of changed plist, entitlement, asset, or project entries |
| API contract changes | Same `xcodebuild` build, plus review against documented WebGuard endpoints |
| Documentation or governance only | Review changed Markdown for accuracy, links, and absence of duplicated or conflicting rules |
| Dependency changes | No dependency manager exists; adding one requires explicit justification and the relevant build validation |

If a command cannot be executed, state why and describe the risk.

## Dependency Management

- This repository currently uses Apple platform frameworks only and has no Swift Package Manager, CocoaPods, Carthage, or lockfile configuration.
- Do not add dependencies without explicit need and review of maintenance, licensing, binary size, privacy, security, and App Store impact.
- Do not introduce duplicate libraries for functionality already covered by Apple frameworks or existing code.
- Do not add or change lockfiles without corresponding dependency changes.
- Do not perform unrelated dependency upgrades or unrequested major-version changes.

## Security, Privacy, and Compliance

- Secrets, credentials, tokens, APNs private keys, provisioning profiles, and production personal data MUST NOT be committed.
- Use Keychain for mobile sessions and access tokens.
- Use UserDefaults only for non-secret local cache data consistent with the privacy manifest.
- Validate user input and remote responses at trust boundaries.
- Do not bypass authentication, authorization, APNs permission flow, Keychain storage, or entitlement requirements.
- Do not log secrets, tokens, passwords, device tokens, private targets, or sensitive account data.
- Do not expose internal error details unnecessarily in user-facing strings.
- Do not disable privacy manifest, APNs entitlement, signing, or security controls without explicit approval.
- Do not add telemetry, analytics, tracking, third-party SDKs, or new external services without approval and privacy documentation.
- Do not upload repository content to external systems without authorization.
- App Store privacy claims and `PrivacyInfo.xcprivacy` MUST remain consistent with app behavior.

## API and Integration Rules

- WebGuard API calls use JSON over HTTPS through `WebGuardAPIClient`.
- Preserve documented endpoint prefixes: `/api/mobile` for mobile session endpoints and `/api/v1` for monitorings and mobile push devices.
- Send bearer tokens only through the `Authorization` header.
- Preserve existing timeout and JSON encoding/decoding behavior unless a task requires changing it.
- Handle `401` and `403` as unauthorized session states.
- Keep APNs payload parsing defensive; ignore push payloads that lack required monitoring identifiers.
- Manual live API or APNs smoke tests require non-production test accounts and must not expose secrets in logs or docs.

## Frontend Rules

- This app is a native SwiftUI frontend, not a web frontend.
- Reuse `Brand` colors, card styling, content-width helpers, and existing layout patterns.
- Provide loading, empty, and error states consistent with nearby screens.
- Keep iPhone portrait and iPad portrait/landscape behavior usable.
- Preserve accessibility basics: readable labels, Dynamic Type-friendly layouts where practical, and tappable controls with clear labels.
- Avoid embedding network, persistence, or APNs logic directly in view bodies.

## Documentation Rules

- Update documentation when setup, validation, environment configuration, API contracts, App Store behavior, or user-facing behavior changes.
- Document non-secret environment and build values in README or focused docs.
- Do not document secrets, private keys, passwords, or production personal data.
- Do not make unverified claims about tooling, tests, CI, privacy, or deployment.
- Do not manually edit generated files unless the repository explicitly requires it.

## Git and Change Scope

- Keep changes limited to the task.
- Do not perform unrelated refactoring or formatting of untouched files.
- Do not overwrite local changes.
- Do not use destructive Git commands.
- Do not commit, push, tag, release, or open pull requests without explicit instruction.
- Do not change CI/CD, infrastructure, entitlements, signing, privacy, or security settings unless required.
- Keep changes small and reviewable.

## Agent Workflow

1. Read the task and acceptance criteria.
2. Read the applicable `AGENTS.md`.
3. Identify and read only relevant skills from `.agent/skills/`.
4. Inspect only relevant files and existing patterns.
5. Evaluate architecture, dependencies, security, privacy, and validation risks.
6. Plan the smallest viable change.
7. Implement the change.
8. Add or update tests when feasible.
9. Run relevant validation commands.
10. Review the diff for unintended changes.
11. Report changes, validation, assumptions, and remaining risks concisely.

Agents MUST NOT begin implementation before checking applicable rules and skills.

## Definition of Done

A task is complete only when:

- Acceptance criteria are met.
- Architecture rules are followed.
- Relevant tests exist or the absence of feasible tests is stated.
- Required validation succeeds or skipped checks are disclosed with reasons.
- No known unnecessary warnings remain.
- Security and privacy requirements are met.
- Documentation is updated where required.
- No unintended files changed.
- Assumptions and remaining risks are stated.
