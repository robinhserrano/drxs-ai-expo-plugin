---
name: accessibility
description: WCAG-aligned accessibility for Expo/React Native — accessibility props, screen reader parity across iOS/Android, touch targets, and focus management.
when_to_use: Use when creating, modifying, or reviewing any user-facing component for screen reader support, touch target sizing, color contrast, or motion sensitivity.
allowed-tools: Read Glob Grep
model: sonnet
---

# Accessibility

Accessibility for Expo/React Native, targeting WCAG 2.2 AA as the default conformance bar across iOS (VoiceOver) and Android (TalkBack).

## Core Standards

Apply these standards to ALL user-facing components:

- **Every interactive element has an accessible name** — `accessibilityLabel` when the visible text isn't sufficient (icon-only buttons), otherwise the visible text itself is enough.
- **Set `accessibilityRole`** on every interactive element (`button`, `link`, `image`, `header`, `search`, etc.) — screen readers announce the role, and it drives expected interaction semantics.
- **Set `accessibilityState`** for toggles, selection, and disabled states (`{ disabled, selected, checked }`) — visual-only state changes are invisible to screen reader users otherwise.
- **Minimum touch target 44×44pt (iOS) / 48×48dp (Android)** — pad a visually smaller tappable icon with `hitSlop` rather than shrinking the touch area to match the icon.
- **Group related content with `accessibilityRole="none"` + a combined label**, or `accessible={true}` on a wrapping `View`, so a screen reader doesn't read out fragmented pieces of one logical unit one at a time.

## Accessible Interactive Element

```tsx
<Pressable
  onPress={onLike}
  accessibilityRole="button"
  accessibilityLabel={isLiked ? 'Unlike post' : 'Like post'}
  accessibilityState={{ selected: isLiked }}
  hitSlop={8}
>
  <HeartIcon filled={isLiked} />
</Pressable>
```

## Grouping Composite Content

```tsx
<View accessible accessibilityRole="summary" accessibilityLabel={`${post.title}, by ${post.author}, ${post.likeCount} likes`}>
  <Text>{post.title}</Text>
  <Text>{post.author}</Text>
  <Text>{post.likeCount} likes</Text>
</View>
```

Without `accessible`/a combined label, a screen reader would announce each `Text` node separately as the user swipes through — three stops for one logical card.

## Live Announcements

For state changes that aren't tied to a focus change (a toast, a form-wide error banner appearing), announce it explicitly:

```typescript
import { AccessibilityInfo } from 'react-native';

AccessibilityInfo.announceForAccessibility('Post saved');
```

## Focus Management

After navigation or a modal opens, move screen reader focus to the new content's heading so users aren't left on stale context:

```tsx
import { findNodeHandle, AccessibilityInfo } from 'react-native';

const headingRef = useRef<View>(null);

useEffect(() => {
  const node = findNodeHandle(headingRef.current);
  if (node) AccessibilityInfo.setAccessibilityFocus(node);
}, []);

<View ref={headingRef} accessibilityRole="header">
  <Text>Post Details</Text>
</View>;
```

## Motion Sensitivity

Respect the OS-level reduced-motion preference for any non-essential animation:

```typescript
import { AccessibilityInfo } from 'react-native';

const [reduceMotionEnabled, setReduceMotionEnabled] = useState(false);

useEffect(() => {
  AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotionEnabled);
  const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotionEnabled);
  return () => sub.remove();
}, []);
```

When `reduceMotionEnabled` is true, skip decorative Reanimated transitions (see the `animations` skill) or replace them with an instant state change — never disable focus-indicating or essential feedback animations, only decorative ones.

## Text Scaling

Never disable font scaling (`allowFontScaling={false}`) to "fix" a layout — that breaks accessibility for users who rely on larger system text sizes. Fix the layout to accommodate scaled text (flexible containers, `numberOfLines` with an explicit "read more" affordance) instead.

## Color Contrast

Verify text-to-background contrast ratios meet WCAG AA (4.5:1 for normal text, 3:1 for large text ≥18pt/14pt bold) when defining theme tokens (see the `theming` skill) — check this when a color token is introduced or changed, not per-component.

## Testing

React Native Testing Library queries by accessible role/label directly, which doubles as an accessibility check — if `getByRole('button', { name: 'Log in' })` can't find the element, it isn't properly labeled for a screen reader either (see the `testing` skill).

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Icon-only button with no `accessibilityLabel` | Screen reader announces nothing meaningful, or falls back to a raw icon name | Explicit `accessibilityLabel` describing the action |
| Touch target sized to match a small icon | Fails minimum target size, hard to tap for motor-impaired users | `hitSlop` to pad the tappable area without changing visual size |
| `allowFontScaling={false}` | Breaks text scaling for users with low vision | Fix layout to handle scaled text instead |
| Fragmented card content with no grouping | Screen reader reads each line as a separate stop, losing the logical grouping | `accessible` + combined `accessibilityLabel` on the wrapping view |
| Decorative animation ignoring reduced-motion preference | Can trigger discomfort for motion-sensitive users | Check `AccessibilityInfo.isReduceMotionEnabled()` and skip/simplify |
