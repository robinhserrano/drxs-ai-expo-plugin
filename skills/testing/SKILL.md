---
name: testing
description: Unit and component testing for Expo/React Native using Jest and React Native Testing Library — mocking, hooks, structure, and coverage patterns.
when_to_use: Use when writing, modifying, or reviewing tests that use package:jest, package:@testing-library/react-native, or when deciding what and how to test a component, hook, or store.
allowed-tools: Read Glob Grep
model: sonnet
---

# Testing

Unit and component testing for Expo/React Native using Jest (via `jest-expo`) and React Native Testing Library.

## Core Standards

Apply these standards to ALL testing work:

- **`@testing-library/react-native` for component tests** — query by role/text/label the way a user would, never by internal implementation detail (no snapshot-only tests as the sole assertion).
- **Test files mirror the source structure** — `features/auth/components/LoginForm.tsx` → `features/auth/components/LoginForm.test.tsx`, colocated next to the file under test.
- **Mock at the module boundary** — native modules (`react-native-mmkv`, `expo-sqlite`, `expo-secure-store`) are mocked with `jest.mock(...)`; application code is not.
- **Stores and pure functions get direct unit tests** — no need to render a component to test a Zustand store or a Zod schema (see `state-management`, `forms`).
- **Async assertions use `waitFor`/`findBy*`**, never an arbitrary `setTimeout`.
- **One behavior per test** — a failing test name should tell you what broke without reading the assertion.

## Project Setup

`jest-expo` as the Jest preset handles the React Native/Expo transform config:

```javascript
// jest.config.js
module.exports = {
  preset: 'jest-expo',
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg)/)',
  ],
  setupFilesAfterEach: ['@testing-library/jest-native/extend-expect'],
  collectCoverageFrom: ['**/*.{ts,tsx}', '!**/coverage/**', '!**/node_modules/**', '!**/*.config.{js,ts}'],
};
```

## Component Tests

```tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native';
import { LoginForm } from './LoginForm';

test('submits with entered credentials', async () => {
  const onSubmit = jest.fn();
  render(<LoginForm onSubmit={onSubmit} />);

  fireEvent.changeText(screen.getByLabelText('Email'), 'user@example.com');
  fireEvent.changeText(screen.getByLabelText('Password'), 'password123');
  fireEvent.press(screen.getByRole('button', { name: 'Log in' }));

  await waitFor(() =>
    expect(onSubmit).toHaveBeenCalledWith({ email: 'user@example.com', password: 'password123' }),
  );
});

test('shows a validation error for an invalid email', async () => {
  render(<LoginForm onSubmit={jest.fn()} />);
  fireEvent.changeText(screen.getByLabelText('Email'), 'not-an-email');
  fireEvent.press(screen.getByRole('button', { name: 'Log in' }));
  expect(await screen.findByText('Enter a valid email')).toBeTruthy();
});
```

Query priority (matches how a user perceives the screen): `getByRole` > `getByLabelText`/`getByPlaceholderText` > `getByText` > `getByTestId` (last resort, when no accessible query works).

## Testing Hooks

```typescript
import { renderHook, waitFor } from '@testing-library/react-native';
import { usePosts } from './usePosts';

test('usePosts returns fetched posts', async () => {
  const { result } = renderHook(() => usePosts({}), { wrapper: createQueryWrapper() });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toEqual(mockPosts);
});
```

## `renderWithProviders` Helper

Wrap `render` once with the app's real providers (theme, query client, navigation stack) so every component test gets a realistic tree without repeating boilerplate:

```tsx
// test/renderWithProviders.tsx
import { render } from '@testing-library/react-native';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/lib/theme';

export function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>{ui}</ThemeProvider>
    </QueryClientProvider>,
  );
}
```

Use this instead of bare `render` for any component that consumes a provider — it keeps individual test files free of provider setup noise.

## Mocking Native Modules

```typescript
jest.mock('expo-secure-store', () => ({
  setItemAsync: jest.fn(),
  getItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

jest.mock('expo-router', () => ({
  useRouter: () => ({ push: jest.fn(), replace: jest.fn(), back: jest.fn() }),
  useLocalSearchParams: () => ({}),
  Link: ({ children }: { children: React.ReactNode }) => children,
}));
```

See the `storage` skill for the MMKV mock and the `local-data` skill for testing Drizzle repositories against a real in-memory database rather than a mock.

## Coverage

Run with `jest --coverage`. Exclude generated and config files via `collectCoverageFrom` (see setup above) rather than sprinkling `/* istanbul ignore */` comments through the codebase. Target coverage is set per-project; treat a drop in coverage on a PR as a signal to look at what's untested, not a number to chase for its own sake.

## E2E (Beyond Unit/Component)

For full end-to-end flows across real navigation and device APIs, use **Maestro** (YAML-based, fast to write, works well with Expo) or **Detox** (deeper native integration, heavier setup) — pick Maestro by default; reach for Detox only when a flow needs assertions Maestro can't express. E2E tests are out of scope for this skill beyond this pointer — they live in their own suite, run against a built app, not under Jest.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Querying by `testID` as the default | Doesn't verify the screen is actually accessible/usable the way a real user experiences it | `getByRole`/`getByLabelText` first; `testID` only when no accessible query applies |
| Snapshot test as the only assertion | Passes trivially after any change once the snapshot is updated; doesn't express intent | Assert specific rendered content/behavior; use snapshots sparingly, if at all |
| `setTimeout` to "wait" for async state | Flaky, slow, doesn't actually synchronize with the state change | `waitFor`/`findBy*` |
| Mocking `@tanstack/react-query` itself | Tests nothing about the actual data-fetching logic | Mock the network/repository layer underneath the query; let TanStack Query run for real in tests |
