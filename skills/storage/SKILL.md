---
name: storage
description: Best practices for key-value storage in Expo/React Native using MMKV, including Zustand persistence and when to use SecureStore instead.
when_to_use: Use when creating, modifying, or reviewing code using package:react-native-mmkv, persisting settings or drafts across app restarts, or deciding between MMKV and expo-secure-store.
allowed-tools: Read Glob Grep
model: sonnet
---

# Storage

Fast synchronous key-value storage for Expo/React Native using MMKV, reserved for non-sensitive data.

## Core Standards

Apply these standards to ALL storage work:

- **MMKV for non-sensitive key-value data** — settings, UI preferences, draft form state, cached flags. It's synchronous and fast enough to read on every render if needed.
- **`expo-secure-store` for anything sensitive** — auth tokens, refresh tokens, API keys. Never put these in MMKV even with encryption enabled — SecureStore uses the OS keychain/keystore, which MMKV's encryption does not replace.
- **One shared MMKV instance** — instantiate once in `lib/storage.ts`, import everywhere; don't create ad-hoc `new MMKV()` instances scattered across files.
- **Namespace keys by feature** — `auth.lastLoginEmail`, `settings.theme`, not bare `lastLoginEmail`, to avoid collisions as the app grows.

## Instance

```typescript
// lib/storage.ts
import { MMKV } from 'react-native-mmkv';

export const storage = new MMKV({
  id: 'app-storage',
  encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY, // non-sensitive-at-rest data; not a secrets store
});
```

Encryption on MMKV protects against casual inspection of the storage file on a rooted/jailbroken device — it is not a substitute for SecureStore when the data itself is a credential.

## Direct Usage

```typescript
storage.set('settings.theme', 'dark');
const theme = storage.getString('settings.theme');

storage.set('auth.isOnboarded', true);
const isOnboarded = storage.getBoolean('auth.isOnboarded');

storage.delete('settings.theme');
```

## Zustand Persistence Adapter

Wrap MMKV as a Zustand-compatible storage engine (see the `state-management` skill for the store side):

```typescript
// lib/storage.ts (continued)
import type { StateStorage } from 'zustand/middleware';

export const mmkvStorage: StateStorage = {
  setItem: (name, value) => storage.set(name, value),
  getItem: (name) => storage.getString(name) ?? null,
  removeItem: (name) => storage.delete(name),
};
```

```typescript
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '@/lib/storage';

export const useSettingsStore = create(
  persist(
    (set) => ({ theme: 'light' as const, setTheme: (theme: 'light' | 'dark') => set({ theme }) }),
    { name: 'settings-store', storage: createJSONStorage(() => mmkvStorage) },
  ),
);
```

## SecureStore for Sensitive Data

```typescript
import * as SecureStore from 'expo-secure-store';

await SecureStore.setItemAsync('authToken', token);
const token = await SecureStore.getItemAsync('authToken');
await SecureStore.deleteItemAsync('authToken');
```

SecureStore is async and slower than MMKV — that's the cost of using the platform keychain/keystore, and it's the correct tradeoff for credentials.

## MMKV vs SecureStore

| | MMKV | SecureStore |
| --- | --- | --- |
| Speed | Synchronous, very fast | Async, keychain-backed |
| Use for | Settings, UI state, drafts, cached flags | Auth tokens, API keys, credentials |
| Backing | Encrypted file on disk (optional key) | OS keychain (iOS) / Keystore (Android) |
| Size limits | Suited to small-to-medium values | Small values only (a few KB) |

## Testing

Mock `react-native-mmkv` at the module boundary in Jest (see the `testing` skill for the general mocking setup) with an in-memory `Map`-backed fake, so store persistence tests don't touch a real MMKV instance:

```typescript
jest.mock('react-native-mmkv', () => {
  const store = new Map<string, unknown>();
  return {
    MMKV: jest.fn().mockImplementation(() => ({
      set: (k: string, v: unknown) => store.set(k, v),
      getString: (k: string) => store.get(k),
      getBoolean: (k: string) => store.get(k),
      delete: (k: string) => store.delete(k),
    })),
  };
});
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Auth tokens stored in MMKV | Bypasses OS-level credential protection even with MMKV encryption enabled | `expo-secure-store` for anything sensitive |
| Multiple `new MMKV()` instances across the codebase | Fragments the key namespace, harder to reason about what's stored | One shared instance from `lib/storage.ts` |
| Bare, unnamespaced keys | Collisions as features grow (`theme` used by two different features) | Namespace keys by feature/domain |
| Storing large JSON blobs as a single MMKV key | Any read/write reparses the whole blob | Split into smaller keyed values, or use `local-data` (Drizzle/SQLite) for structured/relational data |
