---
name: expo-sdk-upgrade
description: Upgrade the Expo SDK version across a project — dependency bumps, eas.json build profile updates, and a breaking-change checklist.
when_to_use: Use when the user says "upgrade Expo SDK", "bump to Expo SDK 52", "update expo", or asks to prep an SDK upgrade PR.
allowed-tools: Bash Read Glob Grep Edit
argument-hint: "[target SDK version]"
model: sonnet
---

# Expo SDK Upgrade

Bump the Expo SDK version and every SDK-aligned dependency, verify native config compatibility, and prepare an upgrade PR.

## Core Standards

- **Upgrade one major SDK version at a time** — don't skip from SDK 50 to 52 in one PR; each major version's changelog assumes the previous one as a starting point, and skipping compounds breaking changes into one unreviewable diff.
- **Let `expo install --check` resolve versions** — never hand-edit dependency versions in `package.json` for Expo-managed packages; version skew between the SDK and its packages is the most common post-upgrade crash cause.
- **Read the target SDK's changelog before touching anything** — breaking changes (deprecated APIs, config schema changes) need code changes beyond a version bump.
- **Run `npx expo-doctor` after upgrading** to catch native config drift before it becomes a build failure.

## Workflow

### Step 1: Confirm the Target Version

If not specified, ask which SDK version to target — default to "the latest stable" only if the user explicitly wants that.

### Step 2: Bump the SDK and Dependencies

```bash
npx expo install expo@^<target-version>
npx expo install --check
```

`expo install --check` reports every installed package whose version doesn't match what the new SDK expects, and can fix them automatically when re-run with `--fix`:

```bash
npx expo install --check --fix
```

### Step 3: Update `eas.json` Build Profiles

Check `eas.json` for a pinned `runtimeVersion` or SDK-dependent build settings and bump them to match:

```json
{
  "build": {
    "production": {
      "channel": "production"
    }
  }
}
```

Most projects use `"runtimeVersion": { "policy": "sdkVersion" }`, which tracks automatically — only hand-edit `eas.json` if the project pins an explicit runtime version.

### Step 4: Review the Breaking-Change Checklist

Read the release notes for every SDK version between the old and new one (not just the target) for:

- Deprecated/removed APIs the codebase uses (grep for the specific module names called out in the changelog).
- `app.json`/`app.config.js` schema changes (renamed or restructured config keys).
- Minimum OS version bumps (iOS/Android) that may drop support for devices the project still targets.
- New required permissions or plugin configuration for existing native modules.

### Step 5: Verify

```bash
npx expo-doctor
npx tsc --noEmit
```

Run the project's test suite and, if available, do a manual smoke test on both platforms — an SDK upgrade is exactly the kind of change where "the types check" is not sufficient proof it works (see the `testing` skill and the project's `green-gate` skill for the full verification loop).

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Hand-editing dependency versions to match a new SDK | Easy to miss a package or introduce a version that doesn't actually match what the SDK expects | `npx expo install --check --fix` |
| Skipping multiple major SDK versions in one PR | Compounds unrelated breaking changes into one unreviewable diff | One major version per PR |
| Skipping the changelog read | Silent breakage from a deprecated API or config schema change not caught by version resolution | Read release notes for every version crossed, not just the target |
| Treating a clean `tsc`/build as proof the upgrade works | Type-checking doesn't catch runtime behavior changes in native modules | Smoke test on both platforms after upgrading |
