---
name: local-data
description: Best practices for local persistence in Expo/React Native using Drizzle ORM and Expo SQLite — schema, migrations, and the repository pattern.
when_to_use: Use when creating, modifying, or reviewing database schemas, migrations, or queries using package:drizzle-orm and package:expo-sqlite.
allowed-tools: Read Glob Grep
model: sonnet
---

# Local Data

Typed, migration-managed local persistence for Expo/React Native using Drizzle ORM over Expo SQLite.

## Core Standards

Apply these standards to ALL local-data work:

- **Schema is defined once in `data/db/schema.ts`** — every table, with Drizzle's typed column builders. Types flow from here into repositories and queries automatically.
- **Migrations are generated, never hand-written SQL diffs** — use `drizzle-kit generate` and commit the generated SQL files.
- **Repositories are the only code that imports the schema directly** — features call repository functions (see `layered-architecture`); nothing outside `data/repositories/` writes a raw Drizzle query.
- **Run migrations on app start**, before any repository is used — a missing/incomplete migration must fail loudly, not silently return empty results.

## Schema

```typescript
// data/db/schema.ts
import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  displayName: text('display_name'),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
});

export const posts = sqliteTable('posts', {
  id: text('id').primaryKey(),
  authorId: text('author_id').notNull().references(() => users.id),
  title: text('title').notNull(),
  body: text('body').notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
});
```

## Client

```typescript
// data/db/client.ts
import { drizzle } from 'drizzle-orm/expo-sqlite';
import { openDatabaseSync } from 'expo-sqlite';
import * as schema from './schema';

const expoDb = openDatabaseSync('app.db');
export const db = drizzle(expoDb, { schema });
```

## Migrations

Configure `drizzle.config.ts` at the project root:

```typescript
import type { Config } from 'drizzle-kit';

export default {
  schema: './data/db/schema.ts',
  out: './data/db/migrations',
  dialect: 'sqlite',
  driver: 'expo',
} satisfies Config;
```

Generate migrations after changing the schema:

```bash
npx drizzle-kit generate
```

Run pending migrations on app start using Drizzle's Expo migrator, typically inside the root layout via `useMigrations` from `drizzle-orm/expo-sqlite/migrator`, and block rendering behind a loading state until it resolves:

```tsx
// app/_layout.tsx
import { useMigrations } from 'drizzle-orm/expo-sqlite/migrator';
import { db } from '@/data/db/client';
import migrations from '@/data/db/migrations/migrations';

export default function RootLayout() {
  const { success, error } = useMigrations(db, migrations);
  if (error) return <MigrationErrorScreen error={error} />;
  if (!success) return <LoadingSpinner />;
  return <Slot />;
}
```

## Repository Pattern

```typescript
// data/repositories/userRepository.ts
import { eq } from 'drizzle-orm';
import { db } from '../db/client';
import { users } from '../db/schema';

export const userRepository = {
  async findById(id: string) {
    return db.query.users.findFirst({ where: eq(users.id, id) });
  },
  async create(user: typeof users.$inferInsert) {
    return db.insert(users).values(user).returning();
  },
  async update(id: string, changes: Partial<typeof users.$inferInsert>) {
    return db.update(users).set(changes).where(eq(users.id, id)).returning();
  },
};
```

Features call `userRepository.findById(id)` — never `db.query.users.findFirst(...)` directly. This keeps the schema and query shape changeable from one place.

## Testing

Point the test database at an in-memory or throwaway file-backed SQLite instance and run the same migrations before each test suite:

```typescript
import { drizzle } from 'drizzle-orm/expo-sqlite';
import { openDatabaseSync } from 'expo-sqlite';

beforeEach(async () => {
  const testDb = drizzle(openDatabaseSync(':memory:'), { schema });
  await migrate(testDb, migrations); // apply the same migrations as production
});
```

Test repository functions directly against this instance — no mocking of Drizzle's query builder; the point of a repository test is confirming the actual SQL behaves as expected.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
| --- | --- | --- |
| Hand-written SQL migration files | Drifts from the schema definition, easy to introduce an inconsistency | Always regenerate with `drizzle-kit generate` after a schema change |
| Feature component importing `data/db/schema.ts` directly | Bypasses the repository abstraction, scatters query logic across features | Route all access through `data/repositories/` |
| Skipping the migration-on-start step | Queries silently fail or hit a stale schema after a schema change ships | Gate app rendering on `useMigrations` completing |
| Mocking Drizzle's query builder in repository tests | Tests pass without proving the actual SQL is correct | Run repository tests against a real (in-memory) SQLite instance |
