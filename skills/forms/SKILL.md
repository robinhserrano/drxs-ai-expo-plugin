---
name: forms
description: Best practices for forms in Expo/React Native using React Hook Form and Zod.
when_to_use: Use when creating, modifying, or reviewing forms, input validation, or code using package:react-hook-form or package:zod.
allowed-tools: Read Glob Grep
model: sonnet
---

# Forms

Schema-first form validation for Expo/React Native using React Hook Form for form state and Zod for validation.

## Core Standards

Apply these standards to ALL form work:

- **Zod schema is the single source of truth for validation** — define it once, derive the TypeScript type from it with `z.infer`, never hand-write a matching interface separately.
- **`zodResolver` wires the schema into React Hook Form** — never write manual `validate` functions duplicating what the schema already expresses.
- **Controlled inputs via `Controller`** for any non-native-`TextInput` component (custom pickers, switches, third-party inputs); register native `TextInput`s directly with `register` where the library in use supports it, otherwise use `Controller` uniformly for consistency.
- **Field-level error messages come from the schema**, not scattered conditional JSX — put the message in `.min(1, 'Required')` etc. so validation and copy live in one place.
- **Submit handler receives already-validated, typed data** — no re-validation inside `onSubmit`.

## Schema-First Setup

```typescript
// features/auth/schemas/loginSchema.ts
import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().min(1, 'Email is required').email('Enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

export type LoginFormData = z.infer<typeof loginSchema>;
```

## Form Component

```tsx
import { useForm, Controller } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { loginSchema, LoginFormData } from '../schemas/loginSchema';

export function LoginForm({ onSubmit }: { onSubmit: (data: LoginFormData) => void }) {
  const { control, handleSubmit, formState: { errors, isSubmitting } } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  return (
    <View>
      <Controller
        control={control}
        name="email"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextInput
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            autoCapitalize="none"
            keyboardType="email-address"
          />
        )}
      />
      {errors.email && <Text style={styles.error}>{errors.email.message}</Text>}

      <Controller
        control={control}
        name="password"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextInput value={value} onChangeText={onChange} onBlur={onBlur} secureTextEntry />
        )}
      />
      {errors.password && <Text style={styles.error}>{errors.password.message}</Text>}

      <Button title="Log in" onPress={handleSubmit(onSubmit)} disabled={isSubmitting} />
    </View>
  );
}
```

## Composing Schemas

Reuse smaller schemas instead of duplicating field rules across forms:

```typescript
const emailField = z.string().min(1, 'Email is required').email('Enter a valid email');

export const loginSchema = z.object({ email: emailField, password: z.string().min(8) });
export const signUpSchema = z.object({
  email: emailField,
  password: z.string().min(8),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ['confirmPassword'],
});
```

`.refine()` handles cross-field validation (password confirmation, date ranges) — attach the error to the specific field via `path` so it renders in the right place.

## Submitting with a Mutation

Combine with the `server-state` skill's mutation hooks — `handleSubmit` passes typed, validated data straight to the mutation:

```tsx
const { mutate, isPending } = useLogin();
<Button title="Log in" onPress={handleSubmit((data) => mutate(data))} disabled={isPending} />
```

## Testing

Test the schema directly for validation rules (fast, no rendering needed), and test the form component for submission behavior:

```typescript
test('loginSchema rejects an invalid email', () => {
  const result = loginSchema.safeParse({ email: 'not-an-email', password: 'password123' });
  expect(result.success).toBe(false);
});
```

For the component, use React Native Testing Library: fill fields via `fireEvent.changeText`, press submit, and assert the mock `onSubmit` was called with the expected typed payload (see the `testing` skill).

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Hand-written `validate` functions alongside a Zod schema | Two sources of truth that drift apart | Let `zodResolver` derive validation from the schema alone |
| Duplicate TypeScript interface next to the Zod schema | Types and validation rules can silently diverge | `z.infer<typeof schema>` |
| Validating again inside `onSubmit` | Redundant — `handleSubmit` already guarantees valid data reached the callback | Trust the resolver; keep `onSubmit` focused on the side effect |
| Uncontrolled `TextInput` with manual `useState` per field | Reimplements what React Hook Form already manages, loses schema-derived error wiring | `Controller` (or `register` where supported) |
