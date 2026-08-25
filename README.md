# ListingPack

Rails 8 app for Philippine real-estate agents: listing photos in, branded 1080×1080 posters plus captions out.

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

Optional: set `OPENAI_API_KEY` for live copy/vision. Without it, packs use a Taglish template writer.

## Plans (honest)

- **Free:** 3 packs/month, watermark on posters
- **Pro:** unlimited packs, no watermark
- PayMongo (GCash/Maya) and Facebook auto-post are **not live yet**. Local Unlock Pro is a stub for demos only.

## Deploy on Render

This app is a **Docker Rails** service (not Vercel). Config lives in [`render.yaml`](render.yaml).

### 1. Push the repo to GitHub

Render deploys from Git. Commit these deploy files and push to a GitHub repo.

### 2. Create the Blueprint

1. Open [https://dashboard.render.com](https://dashboard.render.com)
2. **New → Blueprint**
3. Connect the ListingPack GitHub repo
4. Apply [`render.yaml`](render.yaml) (web + Postgres)

### 3. Env vars Render will ask for (`sync: false`)

| Key | Value |
|-----|--------|
| `RAILS_MASTER_KEY` | Contents of local `config/master.key` (one line, no newline). **Never commit this file.** |
| `APP_HOST` | Your Render hostname after first deploy, e.g. `listingpack.onrender.com` (no `https://`) |
| `OPENAI_API_KEY` | Optional. Leave blank to use Taglish templates |

Already set by the blueprint: `DATABASE_URL`, `SOLID_QUEUE_IN_PUMA=true`, `CHROME_PATH`, disk at `/rails/storage`.

### 4. After first successful deploy

1. Set `APP_HOST` to the real `*.onrender.com` host and **Manual Deploy → Clear build cache & deploy** once if needed.
2. Seed demo users from **Render Shell**:

```bash
./bin/rails db:seed
```

Or set `SEED_ON_BOOT=true`, restart once, then set it back to `false`.

3. Open `https://YOUR-APP.onrender.com` and log in with the demo accounts above.

### 5. Notes / gotchas

- **Plan size:** Starter web + small Postgres. Chromium for posters needs RAM — Free web often OOMs.
- **Region:** Blueprint defaults to `singapore` (closer to PH). Change in `render.yaml` if you prefer.
- **Storage:** Photos/PNGs land on the Render disk. For multi-instance later, switch Active Storage to S3/R2.
- **Password reset email:** SMTP is not configured yet; forgot-password will not send until you add a mailer.
- **Health check:** `/up`

## Stack

Rails 8, Hotwire, Tailwind, PostgreSQL, Solid Queue (production), Active Storage, Ferrum (Chrome HTML → PNG).
