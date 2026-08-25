# Muslim 5 API

A small Cloudflare Worker + D1 backend for linking Muslim 5 users and showing
their initials on completed prayer cards. Bun is used for local package scripts;
the deployed code runs in the Cloudflare Workers runtime.

Production: [muslim5.purbojati.workers.dev](https://muslim5.purbojati.workers.dev)

- Worker name: `muslim5`
- D1 database: `salah-streak`
- API version: `v1`

## What is synced

- Nickname and app-defined avatar key
- A random linking code
- Links between two users
- Whether a prayer was completed on a given local calendar date

Timing status, attendance, streaks, location, and prayer times remain local to
the iPhone. The service uses request-based HTTPS synchronization, not WebSockets
or server push.

## Local setup

```sh
bun install
bun run cf-typegen
bun run db:migrate:local
bun run dev
```

The local API is available at `http://localhost:8787`. D1 data is kept under
`.wrangler/` and is ignored by Git.

## Authentication model

`POST /v1/users` creates an anonymous user and returns a 64-character private
token once. Store that token in the iOS Keychain. Every protected endpoint uses:

```text
Authorization: Bearer <private-token>
```

The displayed linking code is not an authentication credential. Entering
someone's linking code creates a mutual link immediately, without acceptance.
Either user can unlink later.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Health check |
| `POST` | `/v1/users` | Create an anonymous user and private token |
| `GET` | `/v1/me` | Read profile and linking code |
| `PATCH` | `/v1/me` | Update nickname or avatar |
| `DELETE` | `/v1/me` | Delete the user and their synced data |
| `POST` | `/v1/me/link-code` | Regenerate the linking code |
| `GET` | `/v1/links` | List linked users |
| `POST` | `/v1/links` | Link immediately using `{ "code": "ABCDE-FGHIJ" }` |
| `DELETE` | `/v1/links/:userId` | Unlink a user |
| `PUT` | `/v1/checkins/:date/:prayer` | Mark a prayer completed |
| `DELETE` | `/v1/checkins/:date/:prayer` | Clear a completed prayer |
| `GET` | `/v1/prayers/:date` | Get linked-user avatars grouped by prayer |

Dates use `YYYY-MM-DD`. Prayer values are `fajr`, `dhuhr`, `asr`, `maghrib`, and
`isha`.

## Verify

```sh
bun run cf-typecheck
bun run typecheck
bun run test
bun run deploy:check
```

## Deploy

The production D1 database and its binding are already configured in
`wrangler.jsonc`. Authenticate Wrangler, apply any pending migrations, verify the
deployment bundle, and deploy the Worker:

```sh
bunx wrangler login
bun run db:migrate:remote
bun run deploy:check
bun run deploy
```

Apply the migration before connecting a production app. For a public launch,
add Cloudflare rate limiting to registration and linking-code attempts.
