---
name: layered-architecture
description: Feature-folder layered architecture for Expo/React Native apps — routes, features, shared lib, and data layer, with dependency direction rules.
when_to_use: Use when structuring a new Expo app, organizing a growing `app/` or `src/` directory, deciding where a new file belongs, or reviewing whether a change crosses a layer boundary it shouldn't.
allowed-tools: Read Glob Grep
model: sonnet
---

# Layered Architecture

Feature-folder architecture for Expo/React Native: routes stay thin, features own their vertical slice, shared code lives in `lib/`, and persistence lives in `data/`.

---

## Core Standards

Apply these standards to ALL structural decisions:

- **`app/` contains routes only** — Expo Router screens import from `features/`, never the reverse. A route file's body should mostly be composition: import a feature's top-level screen component and render it.
- **One folder per feature under `features/`** — each feature owns its `components/`, `hooks/`, `store/` (state management), and `api/` (server-state queries/mutations). Features do not import from sibling features' internals — share through `lib/` if needed.
- **`lib/` is shared, feature-agnostic code** — UI primitives, hooks with no feature ownership, formatting utilities, the theme, the query client, the MMKV/Drizzle client instances.
- **`data/` owns persistence** — Drizzle schemas, migrations, and repository functions wrapping raw queries. Features call repositories, never raw Drizzle queries directly.
- **Dependency direction is one-way**: `app/` → `features/` → `lib/` and `data/`. Nothing in `lib/` or `data/` imports from `features/` or `app/`.

---

## Folder Structure

```text
app/                          # Expo Router routes — thin, composition only
  _layout.tsx
  (tabs)/
    _layout.tsx
    index.tsx                 # imports features/home
    profile.tsx                # imports features/profile
  auth/
    login.tsx                  # imports features/auth

features/
  auth/
    components/
      LoginForm.tsx
    hooks/
      useLogin.ts
    store/
      authStore.ts             # Zustand store
    api/
      authQueries.ts            # TanStack Query hooks
  home/
    components/
    hooks/
    store/
    api/

lib/
  theme/
  ui/                          # shared design-system primitives (Button, Card, ...)
  query-client.ts              # TanStack Query client instance
  storage.ts                   # MMKV instance
  utils/

data/
  db/
    schema.ts                  # Drizzle schema
    client.ts                  # Expo SQLite + Drizzle client
    migrations/
  repositories/
    userRepository.ts           # wraps schema queries behind a clean API
```

---

## Data Flow

1. **UI component** (in `features/<feature>/components/`) reads state via a store selector or a TanStack Query hook.
2. **Store** (`features/<feature>/store/`) holds local/client state (Zustand). Server state does not belong here — that's TanStack Query's job.
3. **API layer** (`features/<feature>/api/`) defines query keys and query/mutation hooks that call repositories or a network client.
4. **Repository** (`data/repositories/`) wraps Drizzle queries or network calls behind a typed function — the only place that touches `data/db/schema.ts` directly.

Never let a component import `data/db/client.ts` or a schema table directly — always go through a repository, so the storage mechanism can change without touching feature code.

---

## Adding a New Feature

1. Create `features/<feature>/{components,hooks,store,api}` (only the subfolders the feature actually needs — an empty `store/` folder for a feature with no client state is unnecessary).
2. Add a route in `app/` that imports and renders the feature's top-level screen component.
3. If the feature needs persistence, add a repository function in `data/repositories/` — do not reach into `data/db/schema.ts` from the feature.
4. If the feature needs shared UI, check `lib/ui/` first before creating a new one-off component.

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Business logic inside `app/` route files | Couples navigation structure to feature logic, makes routes hard to test | Route files import and render a feature screen component; logic lives in `features/` |
| Feature importing another feature's internals | Creates hidden coupling between features | Share through `lib/`, or lift the shared piece up if it's genuinely cross-feature |
| Component calling Drizzle directly | Bypasses the repository abstraction, scatters query logic | Always go through `data/repositories/` |
| One giant `store/` at the app root | Loses feature ownership, becomes an unreviewable global state blob | Each feature owns its own store slice |
