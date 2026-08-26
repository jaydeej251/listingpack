# ListingPack

Rails 8 app for Philippine real-estate agents: listing photos in, branded 1080×1080 posters plus captions out.

## Where we are

**Phase 8 (first agents / ops).** Phases 0–7 are in code; Phase 9 (multi-format layouts, more vision, Facebook publish) is deferred furnishing. Full map: [docs/ROADMAP.md](docs/ROADMAP.md). First-agent checklist: [docs/FIRST_AGENTS.md](docs/FIRST_AGENTS.md).

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

Poster PNGs need Google Chrome or Chromium installed locally (Ferrum). Without it, copy still generates and packs can be ready with “PNG not ready” + Redraw.

Optional: set `OPENROUTER_API_KEY` or `OPENAI_API_KEY` for live copy/vision. OpenRouter keys (`sk-or-…`) are auto-detected even if you paste them into `OPENAI_API_KEY`. Without a key, packs use a Taglish template writer.

## Plans (honest)

- **Free:** 3 packs/month, watermark on posters
- **Pro:** unlimited packs, no watermark — ₱499/mo via PayMongo when `PAYMONGO_SECRET_KEY` is set
- Local Unlock Pro stub still works without a PayMongo key
- Facebook Page auto-post is Phase 9 (gated until paying agents stick)

## Phase 6 — production hardening

Before charging real agents, configure:

| Concern | What to set |
|---------|-------------|
| Durable files | Cloudflare R2 or S3: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET`, `AWS_ENDPOINT` (R2), `ACTIVE_STORAGE_SERVICE=cloud` |
| Posters | Prefer a Render **Starter** (or larger) web instance — Free 512 MB often OOMs Chromium |
| Postgres | Upgrade off Free DB (30-day expiry) before paying customers |
| Mail | `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAILER_FROM`, `APP_HOST` |
| PayMongo | `PAYMONGO_SECRET_KEY` + webhook URL `https://YOUR_HOST/paymongo/webhooks` for `checkout_session.payment.paid` |
| Admin | Seed Pro user is admin; open **/admin/failures** for failed packs / poster warnings |

### Phase 6 QA checklist

- [ ] Create listing → pack Ready → Download PNG → restart web service → same PNG still downloads (proves R2/S3)
- [ ] Free watermark present; Pro (paid or local stub) has none
- [ ] Kill Chrome / low RAM: captions still Ready with a **Poster warning** + Redraw
- [ ] Forgot password email arrives when SMTP is configured
- [ ] PayMongo test checkout upgrades plan after webhook (or local stub without key)
- [ ] Cold start: first hit after idle may take ~1 minute on Free — landing copy mentions this

## Deploy on Render (Free)

This app is a **Docker Rails** service (not Vercel). Use **manual Free** services — skip Blueprint if it asks you to pay.

### Why the first Blueprint looked paid

The first `render.yaml` used **Starter** web + **paid Postgres** + a **persistent disk** on purpose:

| Need | Paid choice | Free reality |
|------|-------------|--------------|
| Chromium poster PNGs | More CPU/RAM headroom | 512 MB Free often OOMs during render |
| Photo / PNG storage | R2/S3 (`AWS_*`) | Free has **no disks**; without R2/S3 files wipe on spin-down |
| Seed / debug | Render Shell | Free has **no Shell** — use `SEED_ON_BOOT` |
| Postgres | Always-on Basic | Free DB **expires after 30 days** |

Free is fine for a demo; paid + object storage is what you’d want for a reliable agent product.

### 1. Push the repo to GitHub

Already at `https://github.com/jaydeej251/listingpack` if you pushed earlier.

### 2. Create Free Postgres (do this first)

1. Open [https://dashboard.render.com](https://dashboard.render.com)
2. **New → Postgres**
3. Instance type: **Free**
4. Region: **Singapore** (or same region you pick for the web service)
5. Create. Copy the **Internal Database URL** (or External if Internal is unavailable to Free web).

### 3. Create Free Web Service (manual — not Blueprint)

1. **New → Web Service** → connect the ListingPack repo → branch `main`
2. Runtime: **Docker** (Render should detect `Dockerfile`)
3. Instance type: **Free**
4. Docker Command: `./bin/render-start` (override if blank)
5. Health Check Path: `/up`
6. Add env vars:

| Key | Value |
|-----|--------|
| `RAILS_ENV` | `production` |
| `RAILS_MASTER_KEY` | Contents of local `config/master.key` (one line). **Never commit this file.** |
| `DATABASE_URL` | Paste from the Free Postgres service |
| `SOLID_QUEUE_IN_PUMA` | `true` |
| `WEB_CONCURRENCY` | `1` |
| `RAILS_MAX_THREADS` | `2` |
| `CHROME_PATH` | `/usr/bin/chromium` |
| `APP_HOST` | Leave blank first deploy, then set to `YOUR-SERVICE.onrender.com` (no `https://`) |
| `OPENROUTER_API_KEY` or `OPENAI_API_KEY` | Optional. OpenRouter `sk-or-…` keys auto-route to OpenRouter. Blank → Taglish templates |
| `OPENAI_MODEL` | Optional. Default `gpt-4o-mini` (OpenAI) or `openai/gpt-4o-mini` (OpenRouter) |
| `OPENAI_API_URL` | Optional override. Leave blank unless you must pin a custom endpoint |
| `ACTIVE_STORAGE_SERVICE` | `cloud` when using R2/S3 |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_BUCKET` | Object storage |
| `AWS_ENDPOINT` | R2 endpoint URL (skip for AWS S3) |
| `AWS_REGION` | `auto` for R2; real region for S3 |
| `SMTP_ADDRESS` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `MAILER_FROM` | Password reset + receipts |
| `PAYMONGO_SECRET_KEY` | Enables GCash/Maya checkout |
| `SEED_ON_BOOT` | `true` for **one** deploy only (Free has no Shell) |

7. Create Web Service and wait for the build.

### 4. After first successful deploy

1. Note the URL (`https://….onrender.com`).
2. Set `APP_HOST` to that hostname (no scheme).
3. If you used `SEED_ON_BOOT=true`, set it back to `false` and redeploy so seeds don’t re-run forever.
4. Open the site. First hit after idle can take ~1 minute (Free spin-up).

Demo logins (after seed): `agent@listingpack.local` / `password123` and `free@listingpack.local` / `password123`.

### 5. Free-tier gotchas

- **Cold starts:** spins down after ~15 min idle; next request wakes it (~1 min).
- **No persistent disk:** uploads/posters are lost on restart/spin-down. Demo only until S3/R2.
- **No Shell:** cannot `rails db:seed` from the dashboard — use `SEED_ON_BOOT`.
- **Postgres 30-day expiry:** Free DB is deleted after grace unless you upgrade.
- **Poster OOM:** Chromium may crash on Free 512 MB. App/copy can still work; PNG generation is the fragile part.
- **Password reset email:** needs `SMTP_*` env vars (Resend SMTP works).
- **Health check:** `/up`
- **Recruiting agents:** send them `/guide` after signup; track failures at `/admin/failures` (admin users).

Optional: [`render.yaml`](render.yaml) is Free-plan Blueprint-compatible. Prefer the manual steps above if Blueprint still prompts for billing.

## Stack

Rails 8, Hotwire, Tailwind, PostgreSQL, Solid Queue (production), Active Storage (Disk local / S3-compatible production), Ferrum (Chrome HTML → PNG), PayMongo checkout.
