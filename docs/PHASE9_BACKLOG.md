# Phase 9 backlog (after 5–10 paying agents)

Do **not** build these until Pro payers confirm posters are why they stay.

This is **furnishing** after the Phase 8 demo and first agents — not work needed to show the full product loop today. See [ROADMAP.md](ROADMAP.md).

## Candidates

1. **Multi-format layouts + selector** — square 1:1 (feed), story 9:16, landscape 16:9, Facebook banner; agent picks which formats to generate. Extends the Ferrum HTML→PNG pipeline (`Images::RenderTemplate` today fixes `window_size` at 1080×1080; `GeneratedAsset::TEMPLATE_KEYS` is only `just_listed`, `price_card`, `agent_card`).
2. **More design variants within each format** — alternate looks / carousel set beyond the three current square templates.
3. **Multi-photo vision** — analyze more than `photos.first` for caption notes.
4. **Facebook Page publishing** — Meta Graph `pages_manage_posts` only (not personal timeline, groups, or Marketplace). UI stub lives at `/publishing`.

## Explicitly out of scope

TikTok, Reels-as-core-product, CRM, Messenger bot, Agency seats, native mobile app.

## Gate

Exit Phase 8 with real weekly usage and at least a handful of paid Pro accounts before scheduling this work.
