# Skill: Security Review

## Purpose

Assess and protect authentication, token storage, APNs, privacy, and external integration behavior.

## When to Use

Use for explicit security review or any task touching login, logout, bearer tokens, Keychain, UserDefaults cache, APNs tokens, entitlements, privacy manifest, API authorization, logging, or external services.

## When Not to Use

Do not use for changes with no security or privacy relevance unless explicitly requested.

## Required Context

Read root `AGENTS.md`, affected code/configuration, `.gitignore`, privacy manifest, entitlements, README security/privacy sections, and any supplied threat or compliance requirements.

## Relevant Project Areas

`KeychainStore`, `AppState`, `WebGuardAPIClient`, `APNsService`, `LocalCache`, `PrivacyInfo.xcprivacy`, `WebGuard.entitlements`, xcconfig files, README, and App Store docs.

## Procedure

1. Identify sensitive data involved: password, access token, APNs token, user ID, email, device ID, monitoring data, or private targets.
2. Verify storage location, logging behavior, transport, and permission flow.
3. Check that privacy manifest and App Store disclosures remain accurate.
4. Check that auth failures, logout, and device revocation remain safe.
5. Prefer restrictive defaults and no new external services.

## Validation

Run the documented build if files change. For review-only work, report inspected files and material findings.

## Expected Output

Report findings by severity or state that no material issues were found, plus validation and residual risk.

## Constraints

Do not include secrets, private keys, tokens, production personal data, or exploit instructions beyond what is needed to explain a finding.

## Completion Criteria

Security/privacy impacts are reviewed, necessary fixes or disclosures are made, and remaining risks are explicit.
