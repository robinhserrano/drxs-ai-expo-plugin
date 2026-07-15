---
name: state-management
description: Best practices for client-side state management in Expo/React Native using Zustand and React Context.
when_to_use: Use when writing, modifying, or reviewing code that uses package:zustand, React Context for state, or when deciding between local state, Context, and a store.
allowed-tools: Read Glob Grep
model: sonnet
---

# State Management

Client-side state management for Expo/React Native apps using Zustand as the default store, with React Context reserved for narrower cases.

---

## Core Standards

Apply these standards to ALL state management work:

- **Zustand for shared client state** — any state read or written by more than one component that isn't server data (that's TanStack Query's job — see `server-state`).
- **Plain `useState`/`useReducer` for component-local state** — don't reach for a store when no other component needs the value.
- **React Context only for narrow, rarely-changing values** — theme, locale, auth session object passed to a subtree. Context re-renders every consumer on every change; it is not a general state manager.
- **One store per feature/domain concern** — never a single global app-wide store. See `layered-architecture` for where a feature's store lives.
- **Immutable updates** — always return a new object from `set()`; never mutate `state` in place.
- **Selectors to avoid over-rendering** — read only the slice a component needs: `useStore((s) => s.value)`, not `useStore()` destructured wholesale.
- **No business logic in components** — components call store actions and render state; the store computes the new state.

---

## Zustand Store

```typescript
import { create } from 'zustand';

interface CounterState {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

export const useCounterStore = create<CounterState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));
```

Usage — always select the narrowest slice:

```tsx
// Good — only re-renders when `count` changes
const count = useCounterStore((s) => s.count);
const increment = useCounterStore((s) => s.increment);

// Avoid — re-renders on any store change, and destructuring loses selector benefits
const { count, increment } = useCounterStore();
```

## Slices for Larger Stores

Split a growing store into slices and compose them, rather than one flat object with dozens of fields:

```typescript
interface AuthSlice {
  user: User | null;
  login: (user: User) => void;
  logout: () => void;
}

interface SettingsSlice {
  theme: 'light' | 'dark';
  setTheme: (theme: 'light' | 'dark') => void;
}

const createAuthSlice = (set: SetState): AuthSlice => ({
  user: null,
  login: (user) => set({ user }),
  logout: () => set({ user: null }),
});

const createSettingsSlice = (set: SetState): SettingsSlice => ({
  theme: 'light',
  setTheme: (theme) => set({ theme }),
});

export const useAppStore = create<AuthSlice & SettingsSlice>((set, get, api) => ({
  ...createAuthSlice(set),
  ...createSettingsSlice(set),
}));
```

## Persistence with MMKV

Persist a store across app restarts using Zustand's `persist` middleware with an MMKV-backed storage adapter (see the `storage` skill for the adapter itself):

```typescript
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '@/lib/storage';

export const useSettingsStore = create(
  persist(
    (set) => ({
      theme: 'light' as const,
      setTheme: (theme: 'light' | 'dark') => set({ theme }),
    }),
    { name: 'settings-store', storage: createJSONStorage(() => mmkvStorage) },
  ),
);
```

Only persist state that should survive an app restart (settings, draft form data). Don't persist server data — that belongs in TanStack Query's cache, which has its own persistence story.

## When to Reach for Context Instead

Use Context when the value is:

- Set once near the app root and rarely changes (theme object, i18n instance, an injected service/repository).
- Needed by every descendant of a subtree regardless of depth, and re-render cost of the whole subtree on change is acceptable or the value truly never changes after mount.

```tsx
const ThemeContext = createContext<Theme | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const theme = useAppStore((s) => (s.theme === 'dark' ? darkTheme : lightTheme));
  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;
}
```

Note the pattern above: Context distributes a value: the Zustand store still owns the mutable state and the update logic.

## Testing

Zustand stores are plain functions — test them directly without rendering a component:

```typescript
import { useCounterStore } from './counterStore';

beforeEach(() => {
  useCounterStore.setState({ count: 0 });
});

test('increment increases count by 1', () => {
  useCounterStore.getState().increment();
  expect(useCounterStore.getState().count).toBe(1);
});
```

Reset the store's state in `beforeEach` — Zustand stores are module-level singletons and leak state across tests otherwise.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Server data (API responses) stored in Zustand | Duplicates TanStack Query's cache, loses refetch/invalidation/retry for free | Server data goes through `server-state` (TanStack Query); Zustand holds only client state |
| One giant global store | Impossible to review, every feature coupled to every other | One store per feature/domain, composed via slices if needed |
| Destructuring the whole store in a component | Re-renders on every store change | Select only the fields the component reads |
| Mutating state directly in `set()` | Breaks referential equality, selectors stop detecting changes | Always return a new object |
| Context for frequently-changing state | Re-renders the entire consumer subtree on every update | Zustand with selectors for anything that changes often |
