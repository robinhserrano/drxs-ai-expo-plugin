---
name: license-compliance
description: Dependency license auditing for Expo/React Native projects — categorizes licenses and flags non-compliant or unknown ones.
when_to_use: Use when the user says "check licenses", "license audit", "are our dependencies compliant", or before a release that requires license compliance review.
allowed-tools: Bash Read
argument-hint: "[allowed-license-list]"
model: haiku
---

# License Compliance

Audit npm dependency licenses and produce a compliance report categorized by permissiveness.

## Core Standards

- **Use `license-checker` to enumerate every dependency's license** — never eyeball `package.json` files by hand; transitive dependencies are the common source of an unexpected copyleft license.
- **Categorize, don't just list** — permissive (MIT, Apache-2.0, BSD, ISC), weak copyleft (LGPL, MPL), strong copyleft (GPL, AGPL), and unknown/missing.
- **Flag strong copyleft and unknown licenses for explicit review** — these are the two categories that can create real legal exposure if shipped without sign-off.

## Workflow

### Step 1: Run the Audit

```bash
npx license-checker --production --json > licenses.json
```

`--production` excludes devDependencies (build tooling, test frameworks) from the report — their licenses don't affect the shipped app.

### Step 2: Categorize

Parse `licenses.json` and bucket each package by license family:

| Category | Examples | Typical Risk |
| --- | --- | --- |
| Permissive | MIT, Apache-2.0, BSD-2/3-Clause, ISC, 0BSD | Low — safe to ship as-is |
| Weak copyleft | LGPL-2.1, LGPL-3.0, MPL-2.0 | Low-medium — usually fine for dynamic linking/unmodified use, confirm terms |
| Strong copyleft | GPL-2.0, GPL-3.0, AGPL-3.0 | High — may require open-sourcing the app; needs explicit sign-off |
| Unknown/missing | No `license` field, custom/proprietary text | High — cannot assess risk without manual review of the package |

### Step 3: Cross-Check Against an Allowed List

If the user (or the org) maintains an allowed-license list, flag every package whose license isn't on it — pass the list as the skill's argument, or ask if none is provided and more than a handful of non-permissive licenses turn up.

### Step 4: Produce the Report

Summarize as a table: package name, version, license, category. Call out strong-copyleft and unknown entries explicitly at the top — they're the ones that need a decision, not just a read-through.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Manually scanning top-level `package.json` dependencies only | Misses transitive dependencies, where copyleft licenses most often sneak in | `license-checker` walks the full resolved dependency tree |
| Treating "unknown license" as low-risk by default | An unlicensed or unclearly-licensed package carries more legal uncertainty than a known copyleft one | Flag unknown/missing licenses for explicit manual review, same tier as strong copyleft |
| Including devDependencies in the shipped-app compliance report | devDependency licenses don't affect the distributed app | `--production` flag to scope the audit correctly |
