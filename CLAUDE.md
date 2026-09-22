# Benchd

## What this is

Benchd is a social, identity-layer app for fantasy football — Letterboxd, but for your
fantasy career instead of the movies you've watched. You connect a fantasy account and
the app builds a permanent profile out of it: all-time record, championships, best and
worst draft picks, rivalries. It is deliberately *not* a league host: no live scoring,
no lineup management, no draft tools. It's the companion layer those apps never built.

Data syncs periodically (hourly or on a manual pull), never over game-day websockets.

## v1 scope

v1 is the smallest thing that proves the concept. Build only these:

1. **Sleeper-only profile** — connect one Sleeper account (Sleeper's API is public,
   read-only, and needs no auth). ESPN and Yahoo are v2. Do not add them.
2. **Career stats** — auto-built from synced Sleeper league data: all-time record,
   championships, draft history, win streaks.
3. **Weekly wrap cards** — auto-generated "top performers this week" cards, exportable
   as an image for Twitter/Instagram. This is the growth loop and the single most
   important visual surface in the app. Treat it as such.
4. **Player pages with news** — a page per NFL player with an injury/news feed.
   **No comments, no reactions, no discussion threads in v1.**

Explicitly out of scope for v1: ESPN/Yahoo integration, the social feed, following
friends, comments, year-in-review wraps, live scoring, draft tools, lineup management,
betting integration.

## Rules

### 1. Design is not a phase — it is the product

**This app lives or dies on beautiful, premium UI/UX. Every screen must follow
docs/DESIGN.md. Never ship a default-looking SwiftUI screen.**

A stock `List`, an unstyled `Form`, a system-blue `Button`, default `.navigationTitle`
chrome with no thought behind it — these are bugs, not neutral starting points. If a
screen could have been produced by someone who'd never opened the design doc, it isn't
done. Read `docs/DESIGN.md` before writing any view, and re-read it when in doubt.

The tone is calm and editorial — closer to a lifestyle app than to ESPN or a
sportsbook. Gradient white base, light gray surfaces, light blue used sparingly.
Generous white space. Large, legible numbers, because the numbers are the emotional
payload of this app.

### 2. No paywall. Ever.

Everything in this app is free. There is **no** monetization of any kind in this
version:

- No StoreKit, no `Product`, no `Transaction`, no purchase flows.
- No subscriptions, no premium tier, no "Pro" anything.
- No ads, no ad SDKs, no analytics-for-ad-targeting.
- No feature gating, no paywalled screens, no upsell prompts, no "upgrade" CTAs.
- No locked wrap-card styles, no watermark-removal tier.

The brief in `docs/brief.md` has a "Business model" section. **Ignore it entirely.**
It describes a possible future, not this codebase. If a task seems to call for a paid
tier, it doesn't — push back and build the free version.

## Tech stack

| Layer | Choice |
|---|---|
| App | Native iOS, SwiftUI, **iOS 17+** |
| Concurrency | Swift Concurrency (`async`/`await`, actors). No Combine, no completion handlers. |
| State | `@Observable` MVVM — one `@MainActor @Observable` view model per feature screen |
| Backend | Supabase (Postgres, Auth, Storage) via **supabase-swift** |
| Server logic | Supabase Edge Functions in **TypeScript / Deno** (`supabase/functions/`) |
| Schema | SQL migrations in `supabase/migrations/`, managed by the Supabase CLI |
| Project file | **XcodeGen** — `project.yml` is the source of truth |

`Benchd.xcodeproj` is generated and gitignored. Never hand-edit it; edit `project.yml`
and re-run `xcodegen generate`.

## Conventions

- **Feature-based folders.** Everything a screen needs — views, view model, subviews,
  feature-local models — lives in `Benchd/Features/<Feature>/`. Don't create
  `Views/`, `ViewModels/`, or `Controllers/` layer folders.
- **No third-party UI libraries.** Zero. Not for navigation, not for layout, not for
  charts, not for shimmer effects, not for image loading. If a UI element is needed,
  it gets built in `DesignSystem/`. `supabase-swift` is the only SPM dependency; adding
  another needs a real justification.
- **Every view gets a `#Preview`.** No exceptions — including subviews and states
  (loading, empty, error). Previews use fixtures, never live network calls.
- **No hardcoded colors, fonts, or spacing outside `DesignSystem/`.** No
  `Color(red:green:blue:)`, no `.font(.system(size: 17))`, no `.padding(14)` in a
  feature file. Use the tokens. If a token is missing, add it to `DesignSystem/` and
  use it from there.
- **No secrets in source.** Config comes from `Secrets.xcconfig` → Info.plist →
  `AppConfig`. Never hardcode a URL or key in a `.swift` file.
- Networking lives in `Services/`. Views never call the network; view models call
  services.
- Models in `Models/` are `Sendable` value types. Decode with `Codable` and explicit
  `CodingKeys` rather than relying on key-decoding strategies.

## Layout

```
Benchd/
  App/            App entry point, root navigation, AppConfig
  DesignSystem/   Colors, typography, spacing, shared components. The ONLY place
                  raw design values may appear.
  Features/       Onboarding/ Profile/ Wraps/ Players/ Settings/
  Services/       Supabase/  Sleeper/
  Models/         Shared domain types
  Resources/      Info.plist, Assets.xcassets
BenchdTests/      Unit tests (Swift Testing)
Config/           Shared.xcconfig build settings
supabase/         migrations/ and functions/ (Edge Functions, TS/Deno)
docs/             brief.md, DESIGN.md
```

## Commands

```bash
xcodegen generate          # regenerate Benchd.xcodeproj after changing project.yml
open Benchd.xcodeproj
supabase start             # local Postgres + Auth + Storage
supabase db diff -f <name> # author a new migration
supabase functions serve   # run edge functions locally
```
