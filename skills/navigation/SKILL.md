---
name: navigation
description: Best practices for navigation and routing in Expo/React Native using Expo Router.
when_to_use: Use when creating, modifying, or reviewing routes, layouts, deep links, or navigation logic that uses package:expo-router.
allowed-tools: Read Glob Grep
model: sonnet
---

# Navigation

File-based routing for Expo/React Native apps using Expo Router, built on React Navigation.

## Core Standards

Apply these standards to ALL navigation work:

- **Use `expo-router` for all navigation** — never wire up React Navigation's `NavigationContainer` directly in a project that already has Expo Router installed.
- **Routes live only in `app/`** — a file's path under `app/` *is* its URL; don't hand-roll a separate route config.
- **Use route groups `(group)` to organize without affecting the URL** — e.g. `(tabs)/`, `(auth)/` — the parentheses segment is stripped from the resulting path.
- **`_layout.tsx` defines the navigator for its directory** — `Stack`, `Tabs`, or `Drawer` from `expo-router`, not manually nested `NavigationContainer`s.
- **Prefer `router.push`/`router.replace` or the `<Link>` component over imperative `navigation.navigate`** — Expo Router's typed routes catch path typos at compile time when `experiments.typedRoutes` is enabled.
- **Use `useLocalSearchParams()` for route params** — never parse the URL manually.
- **Hyphens for multi-word URL segments** — never underscores or camelCase in route file/folder names that become URL paths.

## Route Organization

```text
app/
  _layout.tsx                 # Root Stack — wraps providers (Query, Theme, etc.)
  (tabs)/
    _layout.tsx                # Tabs navigator
    index.tsx                  # /  (first tab)
    profile.tsx                 # /profile
  (auth)/
    login.tsx                   # /login
    sign-up.tsx                  # /sign-up
  post/
    [id].tsx                     # /post/:id  — dynamic segment
  modal.tsx                      # presented as a modal via _layout config
```

Route groups (`(tabs)`, `(auth)`) let you nest layouts and organize files without those segments appearing in the URL.

## Typed Routes

Enable typed routes in `app.json`:

```json
{
  "expo": {
    "experiments": { "typedRoutes": true }
  }
}
```

With typed routes on, `<Link href="/post/[id]" params={{ id: "1" }} />` and `router.push` are checked against the actual `app/` file structure at build time — a typo in the path is a type error, not a runtime 404.

## Navigation Methods

| Method | URL Updates | Back Stack | Use Case |
| --- | --- | --- | --- |
| `router.push(href)` | Yes | Adds entry | Standard forward navigation |
| `router.replace(href)` | Yes | Replaces current entry | Redirect after login, onboarding steps |
| `router.back()` | Yes | Pops entry | Programmatic back |
| `<Link href={...}>` | Yes | Adds entry | Declarative navigation in JSX — prefer this over `onPress={() => router.push(...)}` for simple links |

```tsx
import { Link, router } from 'expo-router';

// Declarative
<Link href={{ pathname: '/post/[id]', params: { id: post.id } }}>View post</Link>

// Imperative
router.push({ pathname: '/post/[id]', params: { id: post.id } });
```

## Layouts

```tsx
// app/(tabs)/_layout.tsx
import { Tabs } from 'expo-router';

export default function TabsLayout() {
  return (
    <Tabs>
      <Tabs.Screen name="index" options={{ title: 'Home' }} />
      <Tabs.Screen name="profile" options={{ title: 'Profile' }} />
    </Tabs>
  );
}
```

## Modals

Present a route as a modal by setting its presentation in the parent `_layout.tsx`:

```tsx
// app/_layout.tsx
<Stack>
  <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
  <Stack.Screen name="modal" options={{ presentation: 'modal' }} />
</Stack>
```

## Deep Linking

Expo Router derives deep links from the file structure automatically — `app/post/[id].tsx` is reachable at `<scheme>://post/123` with no extra linking config. Configure the URL scheme in `app.json` (`expo.scheme`) and test with `npx uri-scheme open <scheme>://post/123 --ios`.

## Redirects / Auth Guards

Use a layout-level redirect for auth gating:

```tsx
// app/(auth)/_layout.tsx
import { Redirect, Slot } from 'expo-router';
import { useAuthStore } from '@/features/auth/store/authStore';

export default function AuthLayout() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  if (isAuthenticated) return <Redirect href="/" />;
  return <Slot />;
}
```

## Testing

Wrap screens under test with `expo-router`'s test utilities or mock `expo-router`'s `useRouter`/`useLocalSearchParams` hooks with `jest.mock('expo-router', ...)`. Assert on the mocked `router.push`/`router.replace` calls rather than real navigation state when unit-testing a screen's navigation behavior.

## Common Patterns

### Adding a New Route

1. Create the file under `app/` at the path that should become the URL.
2. If it needs a distinct navigator (e.g. its own stack), add a `_layout.tsx` in a new folder.
3. Import the actual screen UI from `features/<feature>/components/` — keep the route file thin (see the `layered-architecture` skill).
4. Add a `<Link>` or `router.push` call from wherever the user triggers navigation to it.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Manual `NavigationContainer` alongside Expo Router | Two navigation systems fighting for control | Let Expo Router own the navigator tree entirely |
| Business logic inside a route file | Couples URL structure to feature logic | Route file renders a feature component; logic lives in `features/` |
| Underscore/camelCase URL segments | Inconsistent, non-idiomatic URLs | Hyphens for multi-word segments |
| Parsing `useSegments()` manually instead of `useLocalSearchParams()` | Reinvents what the hook already gives you | Use `useLocalSearchParams()` for route params |
