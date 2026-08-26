# ListingPack roadmap

**Current phase: 8 (first agents / ops).** Product code for Phases 0–7 is in the repo. Phase 9 is gated and not started.

## Phase map

| Phase | Name | Status |
|-------|------|--------|
| 0–5 | MVP studio | Done — auth, brand kit, listings, 8 captions, 3×1080 posters, weekly calendar, quota/watermark |
| 6 | Harden | Code done; host QA in [README.md](../README.md) still unchecked (R2/S3, Chrome/RAM, SMTP) |
| 7 | Billing | Code done; needs `PAYMONGO_SECRET_KEY` in production (local Unlock Pro stub works) |
| **8** | **First agents** | **Current** — [/guide](/guide), [/admin/failures](/admin/failures), [FIRST_AGENTS.md](FIRST_AGENTS.md). Recruiting/ops, not new features |
| 9 | Pack depth | Deferred — [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md) + `/publishing` stub |

## Full product demo today

Brand kit → listing → OpenRouter captions → 3 branded PNGs → download + paste (see `/guide`).

That is enough to demo vs captions-only tools. Multi-format layouts (story, 16:9, banner, selector) are **Phase 9 furnishing**, not a demo blocker. Do not pull them into Phase 8.

## What still must be done

### Phase 8 (now)

1. Run [FIRST_AGENTS.md](FIRST_AGENTS.md): domain/`APP_HOST`, R2/S3, SMTP, optional PayMongo.
2. Check off Phase 6 QA in the README (persist PNG after restart, watermark, Redraw, mail, checkout).
3. Demo the loop with seed users or a real agent; watch `/admin/failures`.
4. Collect a week of feedback before unlocking Phase 9.

### Phase 9 (later — after payers stick)

See [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md). Primary candidate: multi-format layouts + selector, then design variants, multi-photo vision, Facebook Page publishing.
