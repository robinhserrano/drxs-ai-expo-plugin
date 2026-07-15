---
name: lists
description: Best practices for performant list rendering in Expo/React Native using FlashList.
when_to_use: Use when creating, modifying, or reviewing any scrollable list, using package:@shopify/flash-list, or replacing a FlatList/ScrollView-mapped list with a performant equivalent.
allowed-tools: Read Glob Grep
model: sonnet
---

# Lists

Performant list rendering for Expo/React Native using FlashList in place of `FlatList` or a mapped `ScrollView`.

## Core Standards

Apply these standards to ALL list work:

- **Use `FlashList` for any list beyond a handful of static items** — never `ScrollView` + `.map()`, and prefer it over `FlatList` for anything performance-sensitive.
- **Always set `estimatedItemSize`** — FlashList's recycling model depends on it; a missing or wildly wrong estimate defeats the performance benefit.
- **Memoize `renderItem`** — wrap in `useCallback`, and memoize the row component itself with `React.memo` so unrelated list re-renders don't re-render every row.
- **Never pass inline arrow functions or object literals as item props** — they break memoization by creating a new reference every render.
- **Stable `keyExtractor`** — use a real unique id from the data, never the array index, for any list where items can reorder, insert, or delete.

## Basic Usage

```tsx
import { FlashList } from '@shopify/flash-list';

function PostList({ posts }: { posts: Post[] }) {
  const renderItem = useCallback(({ item }: { item: Post }) => <PostRow post={item} />, []);

  return (
    <FlashList
      data={posts}
      renderItem={renderItem}
      estimatedItemSize={80}
      keyExtractor={(item) => item.id}
    />
  );
}

const PostRow = React.memo(function PostRow({ post }: { post: Post }) {
  return (
    <View style={styles.row}>
      <Text style={styles.title}>{post.title}</Text>
    </View>
  );
});
```

## Avoiding Broken Memoization

```tsx
// Avoid — a new function/object reference every render defeats React.memo on the row
<FlashList
  data={posts}
  renderItem={({ item }) => <PostRow post={item} onPress={() => handlePress(item.id)} />}
/>

// Better — pass a stable callback, let the row look up what it needs via its own id
const handlePress = useCallback((id: string) => { /* ... */ }, []);
const renderItem = useCallback(
  ({ item }: { item: Post }) => <PostRow post={item} onPress={handlePress} />,
  [handlePress],
);
```

## Estimating Item Size

`estimatedItemSize` should be the average rendered height (or width, for horizontal lists) in points — get it by measuring a representative row, not guessing. A significantly wrong estimate causes visible jumpiness during fast scrolling; FlashList self-corrects over time but a good estimate avoids the initial mis-layout.

## Headers, Footers, and Empty States

```tsx
<FlashList
  data={posts}
  renderItem={renderItem}
  estimatedItemSize={80}
  ListEmptyComponent={<EmptyState message="No posts yet" />}
  ListHeaderComponent={<PostListHeader />}
  ListFooterComponent={isFetchingNextPage ? <LoadingSpinner /> : null}
  onEndReached={fetchNextPage}
  onEndReachedThreshold={0.5}
/>
```

## Pairing with TanStack Query (Infinite Lists)

```tsx
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: postKeys.list(filters),
  queryFn: ({ pageParam }) => fetchPosts({ ...filters, cursor: pageParam }),
  getNextPageParam: (lastPage) => lastPage.nextCursor,
  initialPageParam: undefined,
});

const posts = useMemo(() => data?.pages.flatMap((p) => p.items) ?? [], [data]);

<FlashList
  data={posts}
  renderItem={renderItem}
  estimatedItemSize={80}
  onEndReached={() => hasNextPage && fetchNextPage()}
  onEndReachedThreshold={0.5}
  ListFooterComponent={isFetchingNextPage ? <LoadingSpinner /> : null}
/>
```

## Testing

Render the list with React Native Testing Library and assert on the rendered row content, not on FlashList's internals (which are recycling implementation detail):

```tsx
test('renders a row per post', () => {
  const { getByText } = render(<PostList posts={mockPosts} />);
  mockPosts.forEach((post) => expect(getByText(post.title)).toBeTruthy());
});
```

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| `ScrollView` + `.map()` for a long list | Renders every item immediately, no recycling — memory and frame-rate cost grows with list size | `FlashList` |
| Missing `estimatedItemSize` | Defeats FlashList's layout/recycling model | Always provide a measured estimate |
| Inline `renderItem` and inline row callbacks | New function reference every render, breaks `React.memo` on rows | `useCallback` for `renderItem` and any per-row callback |
| `keyExtractor` using array index | Wrong identity after reorder/insert/delete, causes state to attach to the wrong row | Use a stable unique id from the data |
