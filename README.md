# drxs-ai-expo-plugin

A [Claude Code](https://claude.ai/code) plugin that accelerates React Native/Expo development with best-practice skills, covering the 2026 recommended stack: Expo, Expo Router, TypeScript, Drizzle + Expo SQLite, MMKV, Zustand/Context, TanStack Query, FlashList, React Hook Form/Zod, and Reanimated/Gesture Handler. Forked from [vgv-ai-flutter-plugin](https://github.com/VeryGoodOpenSource/very_good_ai_flutter_plugin)'s structure; pairs with [drxs-expo-orbit-workflow](../drxs-expo-orbit-workflow) for workflow orchestration.

## Installation

```text
/plugin marketplace add <your-marketplace-repo>
/plugin install drxs-ai-expo-plugin
```

## Skills

| Skill | Description |
| ----- | ----------- |
| **Create Project** | Scaffold a new Expo app with Expo Router and the recommended stack's dependencies |
| **Layered Architecture** | Feature-folder architecture — routes, features, shared lib, data layer — and dependency direction |
| **Navigation** | Expo Router — file-based routing, typed routes, layouts, groups, modals, deep linking |
| **State Management** | Zustand/Context conventions — slices, selectors, immutable updates, MMKV persistence |
| **Server State** | TanStack Query — query keys, mutations, cache invalidation, optimistic updates |
| **Forms** | React Hook Form + Zod — schema-first validation, resolvers, error display |
| **Local Data** | Drizzle ORM + Expo SQLite — schema, migrations, repository pattern |
| **Storage** | MMKV — key-value storage, encryption, persistence adapters vs SecureStore |
| **Lists** | FlashList — performance-correct list rendering |
| **Testing** | Jest + React Native Testing Library — mocking, hooks, coverage patterns |
| **Animations** | Reanimated + Gesture Handler — shared values, worklets, gesture composition |
| **Theming** | Design tokens, ThemeProvider, light/dark mode |
| **Accessibility** | WCAG-aligned RN accessibility props, screen reader parity, touch targets |
| **Internationalization** | expo-localization + i18next, pluralization, RTL support |
| **Security** | expo-secure-store, OWASP Mobile Top 10, dependency auditing |
| **Expo SDK Upgrade** | `expo install --check`, `eas.json` bumps, breaking-change checklist |
| **License Compliance** | Dependency license auditing and compliance report |
| **Green Gate** | Autonomous lint/format/test/coverage loop, exits only on observed green |

## Agents

| Agent | Description |
| ----- | ----------- |
| **RN Reviewer** | Read-only reviewer of changed `.ts`/`.tsx` against state-management, testing, security, and accessibility standards |

## Hooks

| Hook | Trigger | Behavior |
| ---- | ------- | -------- |
| **Warn Missing Tooling** | SessionStart | Warns if `node`/`npm`/`npx` is missing, or `eas-cli` is absent when `eas.json` exists; non-blocking |
| **Lint** | PostToolUse (`Edit`/`Write` on `.ts`/`.tsx`) | Runs `eslint --fix`; blocking on unresolved errors |
| **Format** | PostToolUse (`Edit`/`Write` on `.ts`/`.tsx`) | Runs `prettier --write`; non-blocking |

### Prerequisites

- Node.js and npm/npx on `PATH`
- ESLint and Prettier configured in the target project (hooks no-op gracefully if missing)

## Usage

Skills activate automatically when Claude detects relevant context, or invoke directly:

```bash
/create-project
/layered-architecture
/navigation
/state-management
/server-state
/forms
/local-data
/storage
/lists
/testing
/animations
/theming
/accessibility
/internationalization
/security
/expo-sdk-upgrade
/license-compliance
/green-gate
```
