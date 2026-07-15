---
name: server-state
description: Best practices for server state in Expo/React Native using TanStack Query — query keys, caching, mutations, and offline behavior.
when_to_use: Use when fetching data from a network API or syncing it with a local database, writing or reviewing code that uses package:@tanstack/react-query, or deciding whether data belongs in a Zustand store or a query cache.
allowed-tools: Read Glob Grep
model: sonnet
---

# Server State

Any data that originates outside the app — a network API, a local database synced with a backend — is **server state**, managed with TanStack Query rather than a client store.

---

## Core Standards

Apply these standards to ALL server-state work:

- **Use TanStack Query for anything fetched, not just anything async** — a `useQuery`/`useMutation` pair, never a manual `useEffect` + `useState` fetch.
- **Query keys are structured arrays, factory-generated** — never ad-hoc string keys scattered across files.
- **Colocate query/mutation hooks with the feature that owns the data**, under `features/<feature>/api/` (see `layered-architecture`).
- **Invalidate, don't refetch manually** — after a mutation, call `queryClient.invalidateQueries` with the relevant key; don't imperatively re-trigger a `useQuery`.
- **Never store query results in Zustand** — read them via `useQuery` wherever needed; the cache is the source of truth.

---

## Query Key Factories

```typescript
// features/posts/api/postKeys.ts
export const postKeys = {
  all: ['posts'] as const,
  lists: () => [...postKeys.all, 'list'] as const,
  list: (filters: PostFilters) => [...postKeys.lists(), filters] as const,
  details: () => [...postKeys.all, 'detail'] as const,
  detail: (id: string) => [...postKeys.details(), id] as const,
};
```

A factory makes invalidation precise: `invalidateQueries({ queryKey: postKeys.lists() })` invalidates every list variant without touching `postKeys.detail(id)` caches.

## Queries

```typescript
// features/posts/api/usePosts.ts
import { useQuery } from '@tanstack/react-query';
import { postKeys } from './postKeys';
import { fetchPosts } from './postsClient';

export function usePosts(filters: PostFilters) {
  return useQuery({
    queryKey: postKeys.list(filters),
    queryFn: () => fetchPosts(filters),
  });
}
```

```tsx
const { data, isLoading, error } = usePosts(filters);

if (isLoading) return <LoadingSpinner />;
if (error) return <ErrorState error={error} />;
return <PostList posts={data} />;
```

## Mutations

```typescript
// features/posts/api/useCreatePost.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { postKeys } from './postKeys';
import { createPost } from './postsClient';

export function useCreatePost() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: createPost,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: postKeys.lists() });
    },
  });
}
```

## Optimistic Updates

Use `onMutate` to update the cache before the server responds, and roll back in `onError`:

```typescript
useMutation({
  mutationFn: updatePost,
  onMutate: async (updated) => {
    await queryClient.cancelQueries({ queryKey: postKeys.detail(updated.id) });
    const previous = queryClient.getQueryData(postKeys.detail(updated.id));
    queryClient.setQueryData(postKeys.detail(updated.id), updated);
    return { previous };
  },
  onError: (_err, updated, context) => {
    queryClient.setQueryData(postKeys.detail(updated.id), context?.previous);
  },
  onSettled: (_data, _err, updated) => {
    queryClient.invalidateQueries({ queryKey: postKeys.detail(updated.id) });
  },
});
```

## Offline / Retry Configuration

Configure the shared `QueryClient` in `lib/query-client.ts` once, not per-hook:

```typescript
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 60_000,
      networkMode: 'offlineFirst',
    },
    mutations: {
      networkMode: 'offlineFirst',
      retry: 1,
    },
  },
});
```

`networkMode: 'offlineFirst'` lets queries return cached data immediately when offline instead of erroring, and lets mutations queue rather than fail outright — pair with `@react-native-community/netinfo` if the app needs to react to connectivity changes directly.

## Provider Setup

```tsx
// app/_layout.tsx
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from '@/lib/query-client';

export default function RootLayout() {
  return (
    <QueryClientProvider client={queryClient}>
      <Slot />
    </QueryClientProvider>
  );
}
```

## Testing

Wrap the hook under test in a fresh `QueryClientProvider` per test, with retries disabled so failures surface immediately:

```typescript
function createWrapper() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

test('usePosts returns fetched posts', async () => {
  const { result } = renderHook(() => usePosts({}), { wrapper: createWrapper() });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toEqual(mockPosts);
});
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| `useEffect` + `useState` fetch | Reinvents caching, dedup, retry, and loading state that TanStack Query already provides | `useQuery` |
| String literal query keys (`'posts'`, `'post-list'`) | Typos silently create separate cache entries; invalidation becomes guesswork | Query key factories |
| Storing fetched data in Zustand | Two sources of truth for the same data; loses cache invalidation | Read directly from `useQuery`'s cache |
| Manual refetch after a mutation | Bypasses the cache, causes redundant network calls | `queryClient.invalidateQueries` |
| One shared `retry: false` globally to "simplify" errors | Hides real transient-failure recovery in production | Configure `retry`/`networkMode` deliberately per environment, not to silence errors during development |
