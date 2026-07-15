---
name: security
description: Static security review for Expo/React Native — secrets management, expo-secure-store, certificate pinning, OWASP Mobile Top 10, and dependency auditing.
when_to_use: Use when reviewing or writing code that handles secrets, authentication tokens, network communication, or user data, or when auditing dependencies for known vulnerabilities.
allowed-tools: Read Glob Grep
model: sonnet
---

# Security

Static security review for Expo/React Native apps — no secrets in source or JS-accessible storage, secure network communication, and dependency hygiene.

## Core Standards

Apply these standards to ALL security-sensitive work:

- **No hardcoded secrets in source** — API keys, tokens, or credentials in a `.ts` file ship inside the JS bundle and are trivially extractable from the built app. Use environment variables injected at build time (`EXPO_PUBLIC_*` for values genuinely safe to expose client-side; a backend proxy for anything that must stay secret).
- **`expo-secure-store` for credentials at rest** — auth tokens, refresh tokens, never MMKV or AsyncStorage even with app-level encryption (see the `storage` skill for the MMKV/SecureStore split).
- **HTTPS only, always** — no `http://` endpoints in production config; use `expo-network` or platform APIs to detect and reject on non-TLS connections if the app might run against a misconfigured environment.
- **`Crypto.getRandomValues` (via `expo-crypto`) for anything security-sensitive** — never `Math.random()` for tokens, nonces, or IDs used in an auth flow.
- **Validate all external input at the boundary** — API responses, deep link params, and QR/barcode-scanned content are untrusted; validate with the `forms` skill's Zod patterns before using the value.

## Secrets and Environment Variables

```bash
# .env (not committed — in .gitignore)
EXPO_PUBLIC_API_URL=https://api.example.com
API_SECRET_KEY=never-put-a-real-secret-here-with-EXPO_PUBLIC-prefix
```

Anything prefixed `EXPO_PUBLIC_` is inlined into the JS bundle at build time and is visible to anyone who unpacks the app — treat it as public configuration, not a secret. A true secret (one the client should never see) belongs behind a backend endpoint the app calls, not in the app's bundle at all.

## Token Storage

```typescript
import * as SecureStore from 'expo-secure-store';

export async function saveAuthToken(token: string) {
  await SecureStore.setItemAsync('authToken', token, {
    keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  });
}
```

`WHEN_UNLOCKED_THIS_DEVICE_ONLY` prevents the token from being included in an iCloud Keychain backup that could be restored to a different device — the right default for session tokens.

## Certificate Pinning

For apps handling especially sensitive data, pin the backend's certificate to prevent MITM via a compromised or malicious CA. Expo's managed workflow requires an EAS Build config plugin (e.g. `react-native-ssl-pinning` or a custom config plugin) since this touches native networking — bare `fetch` cannot pin certificates on its own. Document the pin rotation process alongside the certificate's expiry so an app update ships before an old pin breaks connectivity.

## Random Values

```typescript
import * as Crypto from 'expo-crypto';

const randomBytes = await Crypto.getRandomBytesAsync(16);
const uuid = Crypto.randomUUID();
```

`Math.random()` is not cryptographically secure — never use it to generate a session id, a password-reset token, or anything else where predictability is a security risk.

## Deep Link / External Input Validation

```typescript
import { z } from 'zod';

const resetPasswordParamsSchema = z.object({
  token: z.string().min(1),
  userId: z.string().uuid(),
});

// app/reset-password.tsx
const params = useLocalSearchParams();
const parsed = resetPasswordParamsSchema.safeParse(params);
if (!parsed.success) {
  return <InvalidLinkScreen />;
}
```

Treat deep link params exactly like any other untrusted external input — validate before using them to drive a screen or an API call (see `forms` and `navigation`).

## Dependency Auditing

```bash
npm audit --omit=dev
```

Run this before a release, and address High/Critical findings before shipping. For a broader OWASP Mobile Top 10 pass, check specifically for: insecure data storage (covered above), insecure communication (HTTPS + pinning above), insufficient input validation (covered above), and insecure authentication/session handling (token expiry, refresh flow, logout actually clearing SecureStore).

## OWASP Mobile Top 10 Quick Reference

| Risk | Mitigation in this stack |
| --- | --- |
| Insecure data storage | `expo-secure-store` for credentials; MMKV only for non-sensitive data |
| Insecure communication | HTTPS only; certificate pinning for high-sensitivity apps |
| Insecure authentication | Short-lived access tokens + refresh flow; clear SecureStore fully on logout |
| Insufficient input/output validation | Zod validation at every external boundary (API responses, deep links, scanned codes) |
| Client code quality / insecure randomness | `expo-crypto`'s `getRandomBytesAsync`/`randomUUID`, never `Math.random()` |
| Reverse engineering | Not fully preventable in JS bundles — never rely on client-side obfuscation as the security boundary for anything that actually matters; enforce authorization server-side |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| API key committed directly in a `.ts` file | Ships inside the JS bundle, trivially extractable | Environment variable, or a backend proxy for true secrets |
| Auth token in MMKV or AsyncStorage | Skips OS-level credential protection | `expo-secure-store` |
| `Math.random()` for a reset token or session id | Predictable, not cryptographically secure | `expo-crypto`'s `getRandomBytesAsync`/`randomUUID` |
| Trusting deep link params without validation | Unvalidated external input driving app state or an API call | Zod schema validation at the route boundary |
| Client-side-only authorization checks | Server never re-verifies; a modified client bypasses the check entirely | Enforce every authorization decision server-side; client checks are UX only |
