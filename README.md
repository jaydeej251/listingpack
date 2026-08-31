# ListingPack

Rails 8 app for Philippine real-estate agents: listing photos in, multi-format branded posters (square, story, 16:9, banner) plus captions out.

## Where we are

**Phase 8 (first agents / ops).** Phases 0–7 are in code; Phase 9 (format selector, more vision, Pro Plus auto-publish) is deferred furnishing. Pro one-tap Facebook share from Listings is in product. Full map: [docs/ROADMAP.md](docs/ROADMAP.md). First-agent checklist: [docs/FIRST_AGENTS.md](docs/FIRST_AGENTS.md).

## Run locally

```bash
cd /Users/markdjjunio/Desktop/Projects/listingpack
bin/setup
bin/rails db:seed
bin/dev
```

Open [http://localhost:3000](http://localhost:3000).

Demo users after `bin/rails db:seed`:

| Plan | Email | Password | Notes |
|------|-------|----------|--------|
| Pro | `agent@listingpack.local` | `password123` | Ready listing pack (open Listings) |
| Free | `free@listingpack.local` | `password123` | 1 of 3 packs used; watermark on new posters |

Poster PNGs use **libvips** (`brew install vips` on macOS). Without it, copy still generates and packs can be ready with “PNG not ready” + Redraw.

Optional: set `OPENROUTER_API_KEY` or `OPENAI_API_KEY` for live AI captions. OpenRouter keys (`sk-or-…`) are auto-detected even if you paste them into `OPENAI_API_KEY`. Without a key, packs use a Taglish template writer.

### AI (optional)

| Key | Default | Notes |
|-----|---------|-------|
| `OPENROUTER_API_KEY` or `OPENAI_API_KEY` | — | Live captions; blank → Taglish templates |
| `AI_PHOTO_VISION` | `on` | Set `off` to skip sending the first listing photo to vision (cheaper; captions use form fields only) |
| `AI_MAX_OUTPUT_TOKENS` | model default | e.g. `2048` — lowers OpenRouter’s max completion ceiling (helps thin credit balances) |
| `OPENAI_MODEL` | `gpt-4o-mini` / `openai/gpt-4o-mini` | OpenRouter model id when using OpenRouter |

Photo vision analyzes **`photos.first`** only for caption hints. Poster PNGs never use AI (`POSTER_RENDERER=vips` uses libvips locally).

## Plans (honest)

- **Free:** 3 packs/month, 1 square poster per pack (watermarked). No Facebook share from Listings.
- **Pro:** unlimited packs, all 6 poster formats, no watermark, one-tap Facebook / WhatsApp / copy share — ₱499/mo via PayMongo when `PAYMONGO_SECRET_KEY` is set
- **Pro Plus (later):** optional auto-share to Facebook Page and other social apps — ₱799/mo introductory, not for sale yet
- Local Unlock Pro stub still works without a PayMongo key

## Phase 6 — production hardening

Before charging real agents, configure:

| Concern | What to set |
|---------|-------------|
| Durable files | Cloudflare R2 or S3: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET`, `AWS_ENDPOINT` (R2), `ACTIVE_STORAGE_SERVICE=cloud`. R2 needs the checksum flags already in `config/storage.yml` (`when_required`) — otherwise listing create 500s with “one non-default checksum at a time.” |
| Posters | `POSTER_RENDERER=vips` (default). libvips is bundled in Docker; on Hatchbox install `libvips42` if posters fail. Locally: `brew install vips`. |
| Postgres | Hatchbox-managed Postgres on the droplet (always-on) |
| Mail | `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAILER_FROM`, `APP_HOST` |
| PayMongo | `PAYMONGO_SECRET_KEY` (secret key from the PayMongo dashboard). Hosted checkout talks to PayMongo’s `/v2/checkout_sessions` API — there is no extra GCash/Maya URL to put in env. After payment, set webhook `https://YOUR_HOST/paymongo/webhooks` for `checkout_session.payment.paid` (POST only; opening that URL in a browser is a 404). |
| Admin | Seed Pro user is admin; open **/admin/failures** for failed packs / poster warnings |

### Phase 6 QA checklist

- [ ] Create listing → pack Ready → Download PNG → restart web service → same PNG still downloads (proves R2/S3)
- [ ] Free watermark present; Pro (paid or local stub) has none
- [ ] Poster rendering disabled (`POSTER_RENDERER=off`): captions still Ready with failure copy + Redraw
- [ ] Forgot password email arrives when SMTP is configured
- [ ] PayMongo test checkout upgrades plan after webhook (or local stub without key)

## Deploy on Hatchbox + DigitalOcean

Hatchbox deploys this Rails app onto your droplet: it installs Ruby from `.ruby-version`, runs `assets:precompile` and `db:migrate`, starts Puma, and adds `bin/jobs` for Solid Queue. It does **not** use the Dockerfile or `bin/render-start`.

### 1. Env vars in Hatchbox

Copy secrets from Render, then change the host-specific ones. Hatchbox usually sets `RAILS_ENV=production` and `DATABASE_URL` when you attach Postgres.

**Must change (do not keep the Render hostname):**

| Key | Value |
|-----|--------|
| `APP_HOST` | Public hostname only, no `https://` — e.g. `listingpack.com` or the Hatchbox preview host |
| `ADDITIONAL_HOSTS` | Optional comma list: `www.listingpack.com` or a Hatchbox preview host |
| `RAILS_MASTER_KEY` | Contents of local `config/master.key` (one line). **Never commit this file.** |
| `DATABASE_URL` | Hatchbox Postgres URL (auto if you attached the DB) |

**Copy as-is from Render:**

| Key | Notes |
|-----|--------|
| `OPENROUTER_API_KEY` or `OPENAI_API_KEY` | Blank → Taglish templates |
| `AI_PHOTO_VISION` | `off` on thin OpenRouter balances; `on` sends first photo for caption hints |
| `AI_MAX_OUTPUT_TOKENS` | Optional e.g. `2048` — avoids OpenRouter 402 on low credits |
| `OPENAI_MODEL` | Optional. Default `gpt-4o-mini` / `openai/gpt-4o-mini` |
| `ACTIVE_STORAGE_SERVICE` | `cloud` |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_BUCKET` | Object storage |
| `AWS_ENDPOINT` | R2 endpoint (skip for AWS S3) |
| `AWS_REGION` | `auto` for R2 |
| `AWS_FORCE_PATH_STYLE` | `true` for R2 |
| `SMTP_ADDRESS` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `MAILER_FROM` | Password reset |
| `PAYMONGO_SECRET_KEY` | GCash/Maya checkout |
| `POSTER_RENDERER` | `vips` |
| `POSTER_RENDER_MODE` | `sequential` (default) |

**Do not copy from Render:**

| Key | Why |
|-----|-----|
| `SOLID_QUEUE_IN_PUMA` | Hatchbox already runs `bin/jobs`. Setting this true would run workers twice. |
| `SEED_ON_BOOT` | Hatchbox has SSH. Seed once with `bin/rails db:seed` if you need demo users. |
| `SECRET_KEY_BASE` | Optional. Rails 8 can derive it from `RAILS_MASTER_KEY`. |

**Safe to raise on a droplet (optional):** `WEB_CONCURRENCY=2`, `RAILS_MAX_THREADS=5`, `DB_POOL=10`, `JOB_CONCURRENCY=1`.

### 2. After first deploy

1. Set `APP_HOST` to the live hostname and redeploy (or restart) so cookies, mailer links, and PayMongo return URLs match.
2. Point PayMongo’s webhook at `https://YOUR_HOST/paymongo/webhooks` (`checkout_session.payment.paid`). The old `*.onrender.com` webhook will miss payments.
3. If poster PNGs fail, SSH in and install libvips: `sudo apt-get install -y libvips42 libvips-dev fonts-liberation`.
4. Hatchbox `db:migrate` now also loads Solid Queue/Cache/Cable schemas (they share `DATABASE_URL` unless you set `QUEUE_DATABASE_URL` / `CACHE_DATABASE_URL` / `CABLE_DATABASE_URL`).

Demo logins (after seed): `agent@listingpack.local` / `password123` and `free@listingpack.local` / `password123`.

Health check: `/up`. Failures: `/admin/failures` (admin users). Agent onboarding: `/guide`.

## Stack

Rails 8, Hotwire, Tailwind, PostgreSQL, Solid Queue (production), Active Storage (Disk local / S3-compatible production), libvips (poster PNGs), PayMongo checkout.
