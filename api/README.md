# SWAPPA API

Express + TypeScript backend for SWAPPA (skill-swap platform). Layered architecture:
`routes → middleware → controller → service → model`, with `app.ts` as the app builder
and `server.ts` as the bootstrap (HTTP + Socket.IO + MongoDB).

See the feature spec/plan in `specs/001-skill-swap-platform/`.

## Stack

- Node 20 + TypeScript 5 (module: `nodenext`)
- Express 5, Mongoose 8 (MongoDB, `2dsphere` geo), Socket.IO 4
- Auth: JWT (access + refresh), bcrypt; email OTP verification
- AI: Gemini via `@google/genai` (backend-only; local stub when no API key)
- Monetization: RevenueCat webhooks (subscription + consumable Boost packs)
- Media: Cloudinary (signed uploads); Push: Firebase Cloud Messaging

## Setup

```bash
npm install
cp .env.example .env   # fill MONGO_URI etc. (only MONGO_URI needed for basic local run)
npm run dev            # http://localhost:3000/api/v1/health
```

External services (Gemini, Cloudinary, RevenueCat, FCM) are optional in dev — the code
falls back to safe stubs (e.g. the email code prints to the console) so you can run free.

## Scripts

| Script | Purpose |
|---|---|
| `npm run dev` | Start with reload (ts-node-dev) |
| `npm run build` | Compile to `dist/` |
| `npm start` | Run compiled server |
| `npm test` | Jest + Supertest (in-memory Mongo) |
| `npm run lint` | ESLint |
| `ts-node src/scripts/seedAdmin.ts <email>` | Promote a user to admin |
| `ts-node src/scripts/ensureIndexes.ts` | Sync all MongoDB indexes |

## API surface (`/api/v1`)

Auth · Users · Skills (catalog, admin-managed) · Skill tags · Matches · Conversations ·
Messages · Swaps · Sessions · Reviews · Credits · AI (icebreaker/insight/rematch/profile-optimizer) ·
Subscription · Safety (report/block) · Admin (`/admin/*`) · Notifications · Webhooks (`/webhooks/revenuecat`).

Full contract: `specs/001-skill-swap-platform/contracts/`.

## Implemented vs. pending

Backend user stories US1–US9 are implemented and covered by tests (`npm test`).
Deferred: Flutter `mobile/` app, `admin-web/` panel, cron-based session reminders, and a
load-test harness. The RTC video provider (Agora/LiveKit) is not yet finalized — remote
session join currently mints a placeholder token.
