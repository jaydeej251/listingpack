# ListingPack roadmap

**Living status (focus, issues, beta):** see **[MASTER_PLAN.md](MASTER_PLAN.md)** — update that file when anything changes across chats.

**Current phase: 8 (first agents / ops), with Phase 9 multi-format layouts started.** Product code for Phases 0–7 is in the repo. Packs now ship six formats (square trio + story + 16:9 + banner). Pro one-tap Facebook share from Listings is in product. Remaining Phase 9 items (format selector, more variants, multi-photo vision, Pro Plus auto-publish) stay gated.

## Phase map

| Phase | Name | Status |
|-------|------|--------|
| 0–5 | MVP studio | Done — auth, brand kit, listings, 8 captions, 3×1080 posters, weekly calendar, quota/watermark |
| 6 | Harden | Code done; host QA in [README.md](../README.md) still unchecked (R2/S3, Chrome/RAM, SMTP) |
| 7 | Billing | Code done; needs `PAYMONGO_SECRET_KEY` in production (local Unlock Pro stub works) |
| **8** | **First agents** | **Current** — [/guide](/guide), [/admin/failures](/admin/failures), [FIRST_AGENTS.md](FIRST_AGENTS.md). Pro one-tap share shipped; recruiting/ops continues |
| 9 | Pack depth | **In progress** — six formats shipped; selector / vision / Pro Plus auto-publish still deferred — [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md) |

## Plans

| Plan | Price | Share |
|------|-------|--------|
| Free | ₱0 | No Facebook share from Listings |
| Pro | ₱499/mo | One-tap Facebook / WhatsApp / copy link (public listing page) |
| Pro Plus | ₱799/mo intro — **not for sale yet** | Optional automatic share to Facebook Page and, later, other social apps |

## Full product demo today

Brand kit → listing → OpenRouter captions → 3 branded PNGs → download + paste (see `/guide`). Pro can also tap Share on Listings to open Facebook with the public listing URL.

That is enough to demo vs captions-only tools. Multi-format layouts (story, 16:9, banner) are **shipping**; format selector and other Phase 9 items remain furnishing.

## What still must be done

### Phase 8 (now)

1. Run [FIRST_AGENTS.md](FIRST_AGENTS.md): domain/`APP_HOST`, R2/S3, SMTP, optional PayMongo.
2. Check off Phase 6 QA in the README (persist PNG after restart, watermark, Redraw, mail, checkout).
3. Demo the loop with seed users or a real agent; watch `/admin/failures`.
4. Collect a week of feedback before unlocking Phase 9.

### Phase 9 (later — after payers stick)

See [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md). Primary candidate: multi-format layouts + selector, then design variants, multi-photo vision, then **Pro Plus** optional auto-share to Facebook and other social channels.
