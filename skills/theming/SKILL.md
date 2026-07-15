---
name: theming
description: Design tokens and theming for Expo/React Native — ThemeProvider, StyleSheet-based tokens, and light/dark mode.
when_to_use: Use when creating, modifying, or reviewing colors, spacing, typography, component styles, or light/dark mode support.
allowed-tools: Read Glob Grep
model: sonnet
---

# Theming

Design-token-based theming for Expo/React Native using a `ThemeProvider` and `StyleSheet`, with light/dark mode driven by `useColorScheme`.

## Core Standards

Apply these standards to ALL theming work:

- **Design tokens are the single source of truth for color, spacing, and typography** — no hardcoded hex colors or magic pixel numbers in component styles.
- **One `ThemeProvider` at the app root** — components read the active theme via a `useTheme()` hook, never by importing a color constant directly.
- **`useColorScheme()` drives light/dark selection** — don't hand-roll OS theme detection.
- **`StyleSheet.create` for static styles**; only compute a style inline when it genuinely depends on runtime theme/props, and even then prefer merging a `StyleSheet`-created base with a small dynamic override.

## Design Tokens

```typescript
// lib/theme/tokens.ts
export const spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 } as const;

export const typography = {
  body: { fontSize: 16, lineHeight: 24 },
  title: { fontSize: 24, lineHeight: 32, fontWeight: '700' as const },
  caption: { fontSize: 12, lineHeight: 16 },
};

const palette = {
  blue500: '#3B82F6',
  gray900: '#111827',
  gray100: '#F3F4F6',
  white: '#FFFFFF',
  red500: '#EF4444',
};

export const lightTheme = {
  colors: {
    background: palette.white,
    text: palette.gray900,
    primary: palette.blue500,
    surface: palette.gray100,
    danger: palette.red500,
  },
  spacing,
  typography,
};

export const darkTheme = {
  colors: {
    background: palette.gray900,
    text: palette.white,
    primary: palette.blue500,
    surface: '#1F2937',
    danger: palette.red500,
  },
  spacing,
  typography,
};

export type Theme = typeof lightTheme;
```

## ThemeProvider

```tsx
// lib/theme/ThemeProvider.tsx
import { createContext, useContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { lightTheme, darkTheme, Theme } from './tokens';

const ThemeContext = createContext<Theme>(lightTheme);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const colorScheme = useColorScheme();
  const theme = useMemo(() => (colorScheme === 'dark' ? darkTheme : lightTheme), [colorScheme]);
  return <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  return useContext(ThemeContext);
}
```

To let users override the system preference (a manual light/dark/system toggle in settings), combine this with the `state-management` skill's persisted store: read the stored override first, fall back to `useColorScheme()` only when the user hasn't chosen one.

## Using Tokens in Components

```tsx
function Card({ children }: { children: React.ReactNode }) {
  const theme = useTheme();
  return <View style={[styles.card, { backgroundColor: theme.colors.surface }]}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 12,
    padding: 16, // static structural values are fine directly in StyleSheet.create
  },
});
```

Static structural properties (`borderRadius`, `padding` values that don't vary by theme) belong in `StyleSheet.create`. Only the theme-dependent properties (`backgroundColor`, `color`) are merged in at render time.

## Component Themes

For a design system with many variants of the same component, centralize variant styles rather than branching with inline conditionals in every usage:

```typescript
// lib/ui/Button/Button.styles.ts
export const buttonVariants = (theme: Theme) => ({
  primary: { backgroundColor: theme.colors.primary },
  secondary: { backgroundColor: theme.colors.surface, borderWidth: 1, borderColor: theme.colors.primary },
  danger: { backgroundColor: theme.colors.danger },
});
```

## Alternative: NativeWind

Teams that prefer Tailwind-style utility classes can use NativeWind instead of (or alongside) the `StyleSheet` + `ThemeProvider` approach above — it compiles Tailwind classes to `StyleSheet` objects and supports `dark:` variants natively. This is a project-level choice; if the codebase already uses NativeWind, follow its conventions instead of introducing a second theming system.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Hardcoded hex colors in component styles | Impossible to retheme, dark mode becomes a scattered find-and-replace | Reference `theme.colors.*` tokens |
| Hand-rolled OS theme detection | Reimplements `useColorScheme`, misses OS-level live updates | `useColorScheme()` |
| New `ThemeProvider` per screen | Inconsistent theme values across the app, defeats the point of a single source of truth | One provider at the app root |
| Inline style objects created fresh every render for static styles | Unnecessary allocation on every render, no memoization | `StyleSheet.create` for anything not theme-dependent |
