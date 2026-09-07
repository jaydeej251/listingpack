# ListingPack — Master Plan

**One source of truth** for roadmap, current focus, issues, and beta feedback.  
Update this file whenever focus changes, an issue is raised/resolved, or a beta review lands. New Cursor chats should read this first.

| Field | Value |
|-------|--------|
| **Last updated** | 8 Sep 2026 (BR-1 soft corner credit shipped in code) |
| **Product phase** | **8 — First agents / ops** |
| **Production host** | **listingpackph.online** |
| **Operator** | Founder (Mark) — dedicated `/admin` operator for now |
| **Canonical roadmap detail** | [ROADMAP.md](ROADMAP.md) · [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md) · [FIRST_AGENTS.md](FIRST_AGENTS.md) |
| **View canvas** | `listingpack-master-guide.canvas.tsx` |

---

## 1. Current focus (NOW)

**Phase 8 ops + absorb early beta feedback — not Phase 9 features.**

1. Keep production healthy on **listingpackph.online** (PayMongo already wired + tested in production).
2. Finish remaining host QA if any (R2/S3 PNG persist after restart, SMTP, watermark policy decision).
3. Support **2–3 active testers** building brand kits; push for first listing packs + PNG posts.
4. Log every review in §5–6; Free-tier soft corner credit shipped (**BR-1**). Confirm with testers.
5. Grow toward **5–10** PH agents; ~1 week of usable feedback before Phase 9 build work.

**Do not start now:** format selector, design variants, multi-photo vision, Pro Plus auto-publish, GPT enums/RSpec/ViewComponents rewrite, unlocking more Free formats.

---

## 2. Next focus (AFTER Phase 8 gate)

Gate: real weekly usage + a handful of paid Pro accounts.

Then pull from [PHASE9_BACKLOG.md](PHASE9_BACKLOG.md), in order:

1. Format selector (six formats already ship; agent picks which to generate)
2. More design variants within formats
3. Multi-photo vision (beyond `photos.first`)
4. **Pro Plus** — optional Facebook Page auto-publish (UI stub at `/publishing`)

---

## 3. Roadmap snapshot

| Phase | Name | Status |
|-------|------|--------|
| 0–5 | MVP studio | **Done** |
| 6 | Harden | **Mostly done in prod** — confirm R2 persist + SMTP QA rows |
| 7 | Billing | **Done in production** — PayMongo tested live |
| **8** | **First agents** | **Current** — 2–3 testers on brand kits; domain live |
| 9 | Pack depth | **Gated** |

### Plans (current product)

| Plan | Price | Limits | Share |
|------|-------|--------|-------|
| Free | ₱0 | 3 packs/month, **1 square** poster (`just_listed`), soft corner “ListingPack” credit | No Facebook share from Listings |
| Pro | ₱499/mo | Unlimited packs, all 6 formats, no corner credit | One-tap Facebook / WhatsApp / copy |
| Pro Plus | ₱799 intro — **not for sale** | Same as Pro + optional auto-share later | Page auto-publish (later) |

> Code already limits Free to `FREE_POSTER_KEYS = %w[just_listed]` — one square. Free credit is a soft corner label (BR-1).

---

## 4. Issues tracker

IDs: `LP-###`. Keep newest at top within each section.

### Open

| ID | Raised | Summary | Severity | Notes |
|----|--------|---------|----------|-------|
| LP-003 | 2026-09 | Grow to 5–10 real PH agent testers + more feedback | High | 2–3 already creating brand kits |
| LP-001 | 2026-09 | Remaining host QA (R2 PNG persist after restart, SMTP mail) | Medium | PayMongo done; domain live |
| LP-004 | 2026-09 | Local orphan `users.google_uid` (no migration on main) | Low | Harmless |

### Resolved

| ID | Raised | Resolved | Summary | Resolution |
|----|--------|----------|---------|------------|
| LP-005 | 2026-09-08 | 2026-09-08 | Free watermark too heavy on agent’s photo | Soft corner “ListingPack” credit (BR-1) |
| LP-002 | 2026-09 | 2026-09-08 | Production domain + PayMongo | **listingpackph.online**; PayMongo wired + tested in production |
| LP-010 | 2026-09-07 | 2026-09-07 | GPT WIP (enums, services, RSpec, vendor/bundle) | Nuked; DB strings restored |
| LP-011 | 2026-09-07 | 2026-09-07 | Bundler path dumped gems into repo | Unset path; gitignore vendor/bundle |
| LP-012 | 2026-09 | 2026-09 | GPT engineering roadmap as master plan | Keep docs/ROADMAP.md |

---

## 5. Beta reviewers

Status: `invited` · `active` · `paused` · `churned`.

| ID | Name / handle | Contact | Plan | Status | Invited | Notes |
|----|---------------|---------|------|--------|---------|-------|
| T-001 | *(unnamed)* | — | Free (likely) | active | ~2026-09 | Creating brand kit |
| T-002 | *(unnamed)* | — | Free (likely) | active | ~2026-09 | Creating brand kit |
| T-003 | *(unnamed)* | — | Free (likely) | active | ~2026-09 | Optional 3rd; brand kit |

**Operator:** Mark (founder) at `/admin/login` — agents are not flagged admin.

**How to invite:** signup → `/guide` → Brand kit → one listing pack → download PNG → paste. Pro: Share on Listings.

---

## 6. Beta reviews log

| Review ID | Date | Reviewer | Theme | Plain summary | Fix status |
|-----------|------|----------|-------|---------------|------------|
| R001 | 2026-09-08 | Early free tester | Free watermark | Watermark not needed — photo is already theirs; “LISTINGPACK FREE” text feels too heavy and blocks the image. Prefers limits over a heavy stamp. | **Shipped** → BR-1 soft corner |

### Beta fix backlog

| BR | From review | Work item | Status |
|----|-------------|-----------|--------|
| BR-1 | R001 | Soft corner “ListingPack” credit instead of diagonal Free banner | **shipped** (2026-09-08) |

Statuses: `open` · `in progress` · `shipped` · `wontfix` · `deferred (Phase 9)`.

---

## 7. Decisions log

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-08 | Free = soft corner “ListingPack” credit (not diagonal banner) | R001 — agent photos must stay postable; keep 3 packs + 1 square |
| 2026-09-08 | Domain = listingpackph.online; PayMongo live; founder is admin | Phase 8 production reality |
| 2026-09-07 | Do **not** follow GPT enums/RSpec/ViewComponents as master plan | Wrong priority for Phase 8 |
| 2026-09-07 | Keep Free format count capped (1 square) | Monetization — more formats sell Pro |
| 2026-09 | Pro Plus auto-publish gated until Pros stick | Phase 9 gate |
| 2026-09-08 | This Master Plan is the cross-chat source of truth | Survives new conversations |

---

## 8. How to maintain (for humans + Cursor agents)

1. **Start of a task:** Read §1 Current focus and §4 Open issues.
2. **Change of focus:** Update §1 and §2; bump **Last updated**.
3. **New bug / ops issue:** Add row under §4 Open with next `LP-###`.
4. **Fixed something:** Move row to §4 Resolved with date + resolution.
5. **Beta invite:** Add row in §5 (replace T-00x placeholders with real names when known).
6. **Beta feedback:** Add row in §6; create `BR-#` if work is needed.
7. **Sync the canvas** when this file changes.
8. **Do not** invent a second competing roadmap — detail stays in [ROADMAP.md](ROADMAP.md).

### Out of scope (do not track as Phase 8 work)

TikTok/Reels-as-core, CRM, Messenger bot, agency seats, native app, scheduled `ScheduledPost` worker, expanding free poster formats (story/banner on Free).
