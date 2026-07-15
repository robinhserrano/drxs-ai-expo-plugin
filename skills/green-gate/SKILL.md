---
name: green-gate
description: >
  Drives an Expo/React Native project to a fully green state through an
  autonomous verify-fix-rerun loop across four quality gates — lint, format,
  test, and coverage. Exits only when a single final iteration proves all four
  pass with observed numbers.
when_to_use: >
  Use when the user wants a project driven to a fully passing state, or says
  things like "green gate", "make it green", "get this passing", "get CI
  green", "fix all the lint and test failures", "clean this up before I open a
  PR", "bring coverage to 100", or "loop until everything passes". Prefer this
  over the single-gate testing skill when the request spans multiple gates or
  asks to fix and re-verify until clean.
argument-hint: "[directory]"
allowed-tools: Bash Read Glob Grep Edit Write
model: sonnet
effort: medium
---

# Green Gate

Autonomous quality-gate loop for Expo/React Native projects. Runs four gates —
lint, format, test, coverage — reads real tool output, edits code and tests to
fix failures, and loops until one final iteration proves all four pass
simultaneously with observed numbers. Acts autonomously on objective failures;
escalates only on stalls, genuine ambiguity, or infrastructure failure.

This skill orchestrates tools and edits files. It defers the *how* of writing
tests to the `testing` skill — it never duplicates mocking, structure, or
coverage-pattern guidance.

---

## Core Standards

Apply these to ALL green-gate work:

- **Run gates via the project's own scripts through Bash** — `npm run lint`,
  `npm run format`/`prettier --write`, `npm test -- --coverage`. There is no
  MCP tool layer here (unlike a Dart/Flutter toolchain) — Bash is the direct
  and correct path for every gate in this stack.
- **Never cache green** — re-evaluate every gate every round. Fixing a lint
  error or adding a test file shifts both formatting and the coverage
  denominator, so a previously green gate can regress.
- **Exit only on observed numbers** — the loop terminates only after a single
  final iteration in which lint is clean, format reports zero changes, all
  tests pass, and `min_coverage` is satisfied, all observed in the same round.
  Declaring success from memory is forbidden.
- **Fix root causes, not symptoms** — never weaken a gate to pass it (do not
  delete failing assertions, lower the coverage target to dodge work, or add
  an `/* istanbul ignore */` on reachable code). Escalate genuine
  product/API decisions instead of guessing.
- **Act autonomously on objective failures** — lint errors, red tests, and
  coverage gaps are fixed without re-prompting. Escalate only per the matrix.

---

## The Loop

For each package root (see **Monorepo**), run this algorithm:

1. **Discover** — resolve the package root (the `directory` argument or the
   workspace root); confirm a `package.json` exists. Initialize loop state
   (iteration counter `0`, empty fingerprints, empty touched-files set).
2. **Lint** — run `npm run lint -- --fix` (or `npx eslint . --fix` if no
   script is defined). If errors remain, this is the active gate. Fix, record
   the fingerprint, go to step 7.
3. **Format** — run `npx prettier --write .` (or the project's format script)
   on the package root. If it reports changed files, the gate is now green
   for the next round.
4. **Test** — only if lint is green this round. Run the project's test
   command (`npm test -- --coverage`, typically Jest via `jest-expo`). If
   tests fail, fix, record the fingerprint, go to step 7.
5. **Coverage** — only if tests pass this round. Parse the coverage summary
   (`coverage/coverage-summary.json` or Jest's terminal output) against
   `min_coverage`. If below target, author tests for the ranked
   under-covered files (via the `testing` skill), go to step 7.
6. **Exit** — if all four gates are green in *this same iteration*, confirm
   success with the observed numbers and stop.
7. **Re-verify** — increment the iteration counter, recompute the failure
   fingerprint, check escalation triggers (no progress, oscillation, cap). If
   a trigger fires, escalate; otherwise loop back to step 2 and re-evaluate
   **every** gate.

**One-pass no-op path** — invoked on an already-green project, iteration 1
finds lint clean, format reporting zero changes, all tests passing, and
coverage at or above target. The loop confirms green and exits without editing
a single file.

---

## Loop State

| State | Purpose |
| --- | --- |
| **Iteration counter** | Enforce the cap (default 5, per package) |
| **Per-gate failure fingerprint (prior round)** | Detect no-progress and oscillation |
| **Files touched this round** | Distinguish a no-op round from a no-progress round; populate escalation reports |

Fingerprint keys per gate:

| Gate | Fingerprint |
| --- | --- |
| **Lint** | Sorted set of `rule-id @ file:line` |
| **Format** | Set of files Prettier would change (empty = green) |
| **Test** | Set of failing test names/paths |
| **Coverage** | Observed percentage + sorted set of under-covered files |

- **No progress** — the current failure fingerprint is identical to the prior
  round's, or its failure count did not decrease. Escalate.
- **Oscillation** — the same two gates trade green/red across two consecutive
  rounds. Escalate.

---

## Gate Precedence

Fixed order: **lint → format → test → coverage**.

1. A downstream gate is not assessed until the upstream gate is green this
   round — a lint error can mask a genuine test compile failure; coverage is
   meaningless when tests don't pass.
2. Every gate is re-evaluated every round; green is never cached. Exit
   requires all four green in the same final iteration.

---

## Lint Gate

- Run `npm run lint -- --fix` (or `npx eslint . --fix` if there's no
  package script). ESLint's `--fix` resolves auto-fixable issues before
  diagnostics are read.
- The gate is green when zero errors remain. Treat error-severity rules as
  blocking; address warnings within scope of the fix, but don't let an
  unrelated pre-existing warning block the gate.
- Also run `npx tsc --noEmit` as part of this gate for TypeScript projects —
  a type error is as blocking as a lint error and is cheap to check in the
  same pass.

## Format Gate

- Run `npx prettier --write .` (or the project's format script) each round.
  It reformats the whole project in place, so the gate is observation-based
  (catches manual edits and pre-existing drift, not just files this loop
  touched) and self-fixing.

## Test Gate

- Run the project's test command with coverage enabled
  (`npm test -- --coverage`, or `npx jest --coverage`).
- **`timeout`** — always run under a timeout (e.g. `timeout 120 npm test --
  --coverage`). A hung test (missing `waitFor`, unresolved promise) should
  kill the run rather than stall the loop. A timeout kill is a tool failure,
  not a test failure — escalate it per the matrix.
- The gate is green when every test passes. A failing test is fixed
  autonomously unless it encodes a genuine product decision (escalate per the
  matrix).

## Coverage Gate

- Parse Jest's coverage summary (`coverage/coverage-summary.json`, or the
  terminal table) for the overall percentage and per-file detail.
- **Default target is 100%**, overridable per invocation (e.g. `80`) for
  legacy codebases. Configure `collectCoverageFrom` in `jest.config.js` (see
  the `testing` skill) to exclude generated files, config files, and type
  declaration files from the denominator — 100% should mean 100% of testable,
  hand-written code.
- **When below target**, rank under-covered files by uncovered line count and
  author tests for the highest-impact files first (via the `testing` skill).
- **Unreachable code** — prefer restructuring to remove genuinely dead code
  over an inline coverage-ignore comment; if a line truly cannot be
  exercised (a defensive `else` branch for an impossible state), an inline
  `/* istanbul ignore next -- reason */` is acceptable but must state why, and
  must not be used to dodge a reachable test.

---

## Fixing

- **Fix only failing items** — address the diagnostics, tests, or
  under-covered files surfaced this round. Do not refactor unrelated code
  (YAGNI).
- **Coverage fixes = author tests** — for each ranked under-covered file,
  write tests following `skills/testing/SKILL.md`. Prioritize by uncovered
  line count.
- **Bound files per round** — fix a coherent batch, then re-verify.
- **Never weaken a gate** — no deleted assertions, no lowered target, no
  blanket coverage-ignore comments on reachable code.

---

## Escalation

Stop and surface to the user when:

| Trigger | Detail |
| --- | --- |
| **No progress between rounds** | Identical or non-decreasing failure fingerprint |
| **Oscillation** | The same two gates trade green/red across two rounds |
| **Cap reached, gates still red** | Terminal — report remaining failures per gate with their fingerprints |
| **Real-bug red test** | A failure that looks like a genuine product decision rather than a coding mistake |
| **Ambiguous fix** | Multiple valid resolutions (e.g. change the API vs. adjust the test) — prefer root-cause; escalate when it's a product/API decision |
| **Unreachable-code coverage gap** | Suggest a justified `/* istanbul ignore */` rather than chasing 100% on genuinely dead code |
| **Denominator hygiene** | A generated file not matched by `collectCoverageFrom`'s exclusions — widen the exclusion, don't ignore-comment individual files |
| **Tool/infra failure** | Test command timeout kill, ESLint/TypeScript crash, missing `node_modules` (escalate with the install hint `npm install`) |

When escalating, report the active gate, its current fingerprint, the files
touched, the iteration count, and the specific decision the user must make.

---

## Monorepo

- **All packages must pass** — continue on failure (fix every failing
  package), then confirm each package's result. One package's red gate does
  not abort the others.
- **Per-package iteration budget** — the cap of 5 is per package, not global.
- **Package-root discovery** — walk for `package.json` files (excluding
  `node_modules`) to enumerate packages when `directory` isn't given.
- **Single `min_coverage` applies to all packages** unless the user states a
  per-package override — state the shared target when confirming coverage.

---

## Additional Resources

- `skills/testing/SKILL.md` — how to write Jest unit, React Native Testing
  Library component, and hook tests (structure, mocking, naming).
