---
name: create-project
description: Scaffold a new Expo/React Native project with TypeScript, Expo Router, and the recommended 2026 stack (Zustand, TanStack Query, Drizzle + Expo SQLite, MMKV, FlashList, React Hook Form/Zod, Reanimated/Gesture Handler).
when_to_use: Use when the user says "create a new Expo app", "start a new React Native project", "scaffold an Expo app", or "set up a new mobile app".
allowed-tools: Bash Read Glob Grep
argument-hint: "[project-name]"
model: haiku
---

# Create Project

Scaffold a new Expo/React Native app using `create-expo-app` and install the recommended stack.

---

## Core Standards

- **Always start from `create-expo-app` with the Expo Router template** — never a bare React Native CLI project unless the user explicitly asks for bare workflow.
- **TypeScript is the default** — never scaffold a JavaScript-only project.
- **Ask only for what you cannot infer** — project name is the one required input. Do not ask about optional config (bundle identifier, EAS project id) unless the user brings it up.
- **Install the recommended stack's dependencies after scaffolding**, not before.

---

## Workflow

### Step 1: Gather the Project Name

If the user didn't provide one, use `AskUserQuestion` — this is the only required parameter.

### Step 2: Scaffold

```bash
npx create-expo-app@latest <project-name> --template
```

Choose the **Blank (TypeScript)** template when prompted, or pass a template flag directly if the CLI version supports it. Expo Router ships by default in current `create-expo-app` templates — confirm `expo-router` is in `package.json` after scaffolding; if not, add it (see Step 3).

### Step 3: Install the Recommended Stack

From inside the new project directory:

```bash
npx expo install expo-router react-native-safe-area-context react-native-screens
npx expo install expo-sqlite
npm install zustand @tanstack/react-query drizzle-orm react-native-mmkv \
  react-hook-form zod @hookform/resolvers @shopify/flash-list
npx expo install react-native-reanimated react-native-gesture-handler
npm install -D drizzle-kit
```

Use `npx expo install` (not plain `npm install`) for any package with native code — it resolves the version compatible with the installed Expo SDK. Use plain `npm install` for pure-JS packages (`zustand`, `@tanstack/react-query`, `drizzle-orm`, `zod`, `react-hook-form`, `@hookform/resolvers`).

### Step 4: Verify

Run `npx expo-doctor` to confirm no dependency version mismatches before handing off.

---

## Key Domain Knowledge

- **`npx expo install` vs `npm install`** — packages with native modules (anything wrapping iOS/Android code, e.g. `react-native-mmkv`, `expo-sqlite`, `react-native-reanimated`) must go through `expo install` so Expo pins a version matching the project's SDK. Pure TypeScript/JS packages use plain `npm install`.
- **Project names** — npm package name rules apply: lowercase, hyphens allowed, no spaces. Convert user-provided names with spaces to kebab-case.
- **Monorepo placement** — if the user is adding this Expo app inside an existing monorepo, scaffold into the target subdirectory and confirm workspace tooling (npm/yarn/pnpm workspaces) picks it up; do not initialize a second root `package.json` unnecessarily.

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Bare React Native CLI by default | Loses Expo's managed-workflow tooling (EAS Build, OTA updates, `expo install`) without a stated reason | Default to Expo managed workflow; only go bare on explicit request |
| `npm install` for native packages | Installs a version that may not match the Expo SDK, causing native build failures | `npx expo install <package>` for anything with native code |
| JavaScript template | Loses type safety from the start | Always scaffold TypeScript |
| Asking for bundle identifier/EAS config upfront | Not needed until the user runs a build | Defer until `eas build` or `eas.json` setup is requested |
