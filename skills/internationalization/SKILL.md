---
name: internationalization
description: Internationalization (i18n) and localization (l10n) for Expo/React Native using expo-localization and i18next, including RTL support.
when_to_use: Use when adding, modifying, or reviewing translated strings, locale detection, pluralization, or right-to-left layout support.
allowed-tools: Read Glob Grep
model: sonnet
---

# Internationalization

i18n/l10n for Expo/React Native using `expo-localization` for device locale detection and `i18next`/`react-i18next` for translation and pluralization.

## Core Standards

Apply these standards to ALL i18n work:

- **No hardcoded user-facing strings in components** — every visible string goes through `t('key')`; hardcoded English text in JSX is the most common regression to catch in review.
- **Namespace translation keys by feature** — `auth.login.title`, not a flat global key list, to avoid collisions as the app grows.
- **Detect device locale via `expo-localization`** on startup, with a persisted user override (see `state-management`/`storage`) taking priority if the user picked a language manually.
- **Use i18next's plural/interpolation features**, never string concatenation to build a sentence around a variable.
- **RTL layout uses `I18nManager`**, not manually mirrored flexbox values per component.

## Setup

```typescript
// lib/i18n/index.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import * as Localization from 'expo-localization';
import en from './locales/en.json';
import es from './locales/es.json';

i18n.use(initReactI18next).init({
  resources: { en: { translation: en }, es: { translation: es } },
  lng: Localization.getLocales()[0]?.languageCode ?? 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false }, // React already escapes
});

export default i18n;
```

```json
// lib/i18n/locales/en.json
{
  "auth": {
    "login": {
      "title": "Log in",
      "emailLabel": "Email",
      "submitButton": "Log in"
    }
  },
  "posts": {
    "likeCount_one": "{{count}} like",
    "likeCount_other": "{{count}} likes"
  }
}
```

## Usage

```tsx
import { useTranslation } from 'react-i18next';

function LoginScreen() {
  const { t } = useTranslation();
  return (
    <View>
      <Text accessibilityRole="header">{t('auth.login.title')}</Text>
      <Text>{t('auth.login.emailLabel')}</Text>
      <Button title={t('auth.login.submitButton')} onPress={handleSubmit} />
    </View>
  );
}
```

## Pluralization

```tsx
// Correctly handles "1 like" vs "3 likes" (and per-locale plural rules beyond just singular/plural)
<Text>{t('posts.likeCount', { count: post.likeCount })}</Text>
```

Never build this manually with `count === 1 ? 'like' : 'likes'` — many locales have more plural categories than English's two (Arabic has six), and i18next's `_one`/`_other` (and `_few`/`_many`/etc. where applicable) key suffixes handle that automatically from the `count` value.

## Persisted Language Override

```typescript
// features/settings/store/languageStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '@/lib/storage';
import i18n from '@/lib/i18n';

export const useLanguageStore = create(
  persist(
    (set) => ({
      language: null as string | null,
      setLanguage: (language: string) => {
        i18n.changeLanguage(language);
        set({ language });
      },
    }),
    { name: 'language-store', storage: createJSONStorage(() => mmkvStorage) },
  ),
);
```

On app start, if `useLanguageStore.getState().language` is set, call `i18n.changeLanguage` with it before rendering — otherwise fall back to the device locale detected at init.

## RTL Support

```typescript
import { I18nManager } from 'react-native';

const isRTL = ['ar', 'he', 'fa', 'ur'].includes(currentLanguageCode);
if (I18nManager.isRTL !== isRTL) {
  I18nManager.forceRTL(isRTL);
  // Requires an app reload to take effect — prompt the user or use Updates.reloadAsync()
}
```

Prefer `flexDirection: 'row'` with logical properties (`marginStart`/`marginEnd` over `marginLeft`/`marginRight`, `start`/`end` over `left`/`right`) so layouts mirror automatically under `I18nManager.isRTL` instead of requiring per-component RTL conditionals.

## Testing

Wrap components under test with the real `i18next` instance configured with a minimal test-language resource bundle, and assert on rendered translated text — don't mock `useTranslation` to return raw keys, which hides missing-key regressions.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Hardcoded strings in JSX | Breaks for every non-default locale, easy to miss in review | Always route through `t('key')` |
| Manual singular/plural ternary | Wrong for languages with more than two plural forms | i18next's `count`-based plural key suffixes |
| String concatenation to build a sentence | Word order varies by language; concatenation assumes English grammar | Interpolation within a single translation key: `t('key', { name })` |
| Per-component RTL flexbox overrides | Scattered, easy to miss a component, hard to maintain | `I18nManager` + logical style properties (`marginStart`/`marginEnd`) |
