# Skill: Review Code

## Purpose

Review WebGuard iOS changes for correctness, security, privacy, maintainability, and validation gaps.

## When to Use

Use when asked to review a diff, branch, pull request, commit, or selected files.

## When Not to Use

Do not use to implement fixes unless explicitly requested after the review.

## Required Context

Read root `AGENTS.md`, the relevant diff or files, affected docs/configuration, and validation evidence if available.

## Relevant Project Areas

Changed files plus nearby architecture owners under `ios/WebGuard/App`, configuration, entitlements, privacy manifest, and docs.

## Procedure

1. Prioritize findings that can cause bugs, security/privacy issues, App Store issues, regressions, or missing validation.
2. Ground each finding in a specific file and line where possible.
3. Avoid style-only comments unless they materially affect maintainability or consistency.
4. Check for missing tests or skipped validation.
5. Keep summaries secondary to actionable findings.

## Validation

Do not run validation unless asked or needed to confirm a finding. If run, report the command and result.

## Expected Output

List findings by severity first, then open questions, then a brief validation or risk note.

## Constraints

Do not duplicate the whole diff or restate repository rules.

## Completion Criteria

Findings are actionable, evidence-backed, concise, and focused on material risk.
