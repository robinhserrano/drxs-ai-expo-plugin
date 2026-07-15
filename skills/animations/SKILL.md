---
name: animations
description: Best practices for animations and gestures in Expo/React Native using Reanimated and Gesture Handler.
when_to_use: Use when creating, modifying, or reviewing animations, transitions, or gesture-driven interactions using package:react-native-reanimated or package:react-native-gesture-handler.
allowed-tools: Read Glob Grep
model: sonnet
---

# Animations

Animations and gestures for Expo/React Native using Reanimated (worklet-driven, UI-thread animation) and Gesture Handler (native gesture recognition).

## Core Standards

Apply these standards to ALL animation work:

- **Reanimated for anything beyond a trivial `Animated` API fade** — shared values and `useAnimatedStyle` run on the UI thread, avoiding the JS-thread bridge overhead that causes dropped frames under load.
- **Gesture Handler for any touch-driven interaction beyond a basic `Pressable`** — pan, pinch, swipe-to-dismiss, drag-to-reorder.
- **Compose gestures with `Gesture.Race`/`Gesture.Simultaneous`/`Gesture.Exclusive`**, not manual `PanResponder` coordination.
- **Keep worklets pure** — a function marked `'worklet'` (or used inside `useAnimatedStyle`/gesture callbacks) runs on the UI thread; don't call non-worklet JS functions or touch React state directly from inside one — use `runOnJS` to cross back.
- **Prefer `withTiming`/`withSpring`/`withDecay`** over manually stepping a value in a loop.

## Shared Values and Animated Styles

```tsx
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';

function LikeButton() {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePress = () => {
    scale.value = withSpring(1.2, {}, () => {
      scale.value = withSpring(1);
    });
  };

  return (
    <Pressable onPress={handlePress}>
      <Animated.View style={animatedStyle}>
        <HeartIcon />
      </Animated.View>
    </Pressable>
  );
}
```

## Gesture Handler + Reanimated

```tsx
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { useSharedValue, useAnimatedStyle } from 'react-native-reanimated';

function DraggableCard() {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  const pan = Gesture.Pan()
    .onUpdate((event) => {
      translateX.value = event.translationX;
      translateY.value = event.translationY;
    })
    .onEnd(() => {
      translateX.value = withSpring(0);
      translateY.value = withSpring(0);
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }, { translateY: translateY.value }],
  }));

  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={[styles.card, animatedStyle]} />
    </GestureDetector>
  );
}
```

## Composing Gestures

```tsx
const pan = Gesture.Pan().onUpdate(/* ... */);
const pinch = Gesture.Pinch().onUpdate(/* ... */);
const composed = Gesture.Simultaneous(pan, pinch);

<GestureDetector gesture={composed}>
  <Animated.View style={animatedStyle} />
</GestureDetector>;
```

Use `Gesture.Exclusive(a, b)` when only one of two gestures should win (e.g. a horizontal swipe on a card that also lives inside a vertical scroll view — give the scroll view priority unless the swipe clearly dominates).

## Crossing Back to JS

```tsx
import { runOnJS } from 'react-native-reanimated';

const pan = Gesture.Pan().onEnd((event) => {
  if (event.translationX < -100) {
    runOnJS(onDismiss)(); // onDismiss is a regular JS function / React state setter
  }
});
```

Never call a non-worklet function or set React state directly inside a worklet — wrap it in `runOnJS`.

## Layout Animations

For simple enter/exit/reordering transitions, Reanimated's layout animation API needs no manual shared-value wiring:

```tsx
import Animated, { FadeIn, FadeOut, Layout } from 'react-native-reanimated';

<Animated.View entering={FadeIn} exiting={FadeOut} layout={Layout.springify()}>
  <PostRow post={post} />
</Animated.View>;
```

Reach for layout animations first for list-item enter/exit and reflow; drop down to manual shared values only when the built-in presets don't express the desired motion.

## Screen Transitions

Expo Router screen transitions are configured through the underlying React Navigation options (`animation` on `Stack.Screen`) rather than through Reanimated directly — see the `navigation` skill for route/layout configuration.

## Testing

Animation-driven UI is generally verified visually, not via unit assertions on animated values. Test the underlying trigger logic instead — e.g. that a gesture's `onEnd` handler calls `onDismiss` past the threshold — by extracting that decision into a plain, non-worklet function and unit-testing it directly.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Manual `PanResponder` for drag/swipe | JS-thread gesture handling drops frames under load; reinvents what Gesture Handler already solves | `Gesture.Pan()` composed via Gesture Handler |
| Calling `setState` or a JS closure directly inside a worklet | Throws or silently no-ops — worklets run on a separate JS runtime on the UI thread | `runOnJS(fn)(...)` to cross back to the JS thread |
| Stepping an animated value in a manual timer loop | Reimplements easing/timing that `withTiming`/`withSpring` already provide, and runs on the JS thread | `withTiming`/`withSpring`/`withDecay` |
| Custom fade/slide logic for simple list item enter/exit | More code than the built-in preset, easy to get janky | Reanimated's `entering`/`exiting`/`layout` props |
