# Fantasy Football Social App — Project Brief

2026-09-21 · @Someone

## Overview

A social, identity-layer app for fantasy football, built on the Letterboxd model but for a fantasy career instead of movies watched.

The problem: fantasy managers already treat their leagues like a hobby worth talking about publicly, if there were a good place to do it. ESPN, Yahoo, and Sleeper are built for managing a team (drafting, setting lineups, live scoring), not for expressing a fantasy identity. None of them work across platforms either; ESPN history and Sleeper history live in disconnected silos with no shared profile.

The solution: connect an ESPN, Yahoo, or Sleeper account (or several) and get one cross-platform fantasy football profile: all-time record, championships, best and worst draft picks, rivalries, plus a social feed where player news becomes a discussion thread and weekly performances become shareable, Spotify-Wrapped-style cards.

Deliberately not building: live scoring, lineup management, or draft tools. Those already exist, and they are the parts that break under game-day load on every competitor. This app is a companion layer, not a replacement for a league host.

## Core features

1. **Profile** - connect ESPN / Yahoo / Sleeper account(s); the app builds a career view: all-time record, championships, best and worst draft picks, rivalries, win streaks, spanning every league across every platform a person has played on, not just one.
2. **Player pages** - every NFL player has a page, similar to a Letterboxd movie page. Injuries and news become discussion threads people react to, comment on, and share out.
3. **Weekly wraps** - auto-generated, shareable "top performers this week" cards, styled for posting to Twitter/Instagram. This is the primary growth loop: screenshot-friendly cards pull new users in the way Spotify Wrapped does.
4. **Feed** - see what friends drafted, dropped, and are reacting to, independent of which platform they're playing on.

All four are read/display features built on top of synced league data. None require real-time scoring or write access back to the league host.

## Design direction

Premium, aesthetic, restrained. Feel over flash.

- **Palette:** gradient white as the base, light gray for secondary surfaces and dividers, light blue as an accent used sparingly (active states, key data points, brand moments). No dark mode-first treatment, no saturated team-color theming, no loud gradients.
- **Tone:** calm and editorial, closer to a lifestyle/wellness app than a sportsbook or ESPN-style stats dashboard. This is the same design instinct behind Visualize (Apple Health as calm gradient cards) applied to fantasy football stats.
- **Typography and spacing:** generous white space, clear hierarchy, large legible numbers for stats (records, points, rankings) since numbers are the emotional payload of the app.
- **Shareable cards:** the weekly wrap cards are the single most important visual surface in the app, since they're what gets posted externally. They need to look premium enough that someone is proud to share one - this is the make-or-break design surface, not a secondary feature.

## Data sources and technical notes

- **ESPN Fantasy API** - unofficial but widely used by hobbyist developers to pull public league data (teams, rosters, standings, transactions). No official developer support or documentation; access can change or break without notice.
- **Sleeper API** - publicly documented, read-only, no auth required for many endpoints. The most developer-friendly of the three.
- **Yahoo Fantasy Sports API** - has an official API but requires OAuth and app registration through Yahoo's developer program; more setup overhead than ESPN or Sleeper.
- **Player/injury news** - a separate feed (NFL news API, RSS, or a licensed sports data provider) is needed to populate player pages with real news, independent of fantasy platform data.

**Key technical decision:** this is a periodic-sync app, not a real-time one. Data refreshes on a schedule (e.g., hourly, or on a manual pull), not via live game-day websockets. That sidesteps the infrastructure complexity and reliability problems that cause competitor apps to fail under Sunday traffic.

**Risk to validate early:** since the ESPN and ESPN-adjacent integrations are unofficial, confirm reliable data access before committing the full app design to it.

## MVP scope

**v1 (ships first):**

- Connect a Sleeper account (start with one platform, the easiest API, to prove the concept)
- Auto-built profile: record, championships, draft history for that account
- Weekly top-performer wrap card, shareable as an image
- Basic player pages with news feed (no comments yet)

**v2 (once v1 validates):**

- ESPN and Yahoo integration (multi-platform profile)
- Comments/discussion on player pages
- Social feed (following friends, seeing their activity)
- Year-in-review wrap (the big viral/growth moment)

**Explicitly out of scope for v1 and v2:** live scoring, draft tools, lineup management, betting integration.

## Competitive positioning

- **ESPN, Yahoo, Sleeper, CBS, NFL apps** - all league-hosting and management tools first. Social features (where they exist, like Sleeper's chat) are locked to that one platform's leagues.
- **Sleeper** is the closest comparison: design-led, popular with younger managers, built around a clean interface and chat. But it's not cross-platform, and it's still fundamentally a league-management app, not an identity/social app.
- **No direct "Letterboxd for fantasy football" competitor found.** The cross-platform social/profile layer is an open gap.
- **Common competitor weakness to exploit:** live scoring that lags or freezes, lineups that fail to lock, and late push alerts are recurring complaints across the major fantasy apps on game day. This app avoids that failure mode entirely by design (see Data sources and technical notes).

## Business model

Freemium, similar to Letterboxd's own model (free core product, paid tier around $20/year for stats, personalization, and extras):

- **Free:** profile, player pages, basic weekly wraps, feed
- **Paid tier:** advanced career stats, custom wrap card styles/themes, multi-platform profile merging, ad-free

Not yet decided: exact price point, whether to monetize the shareable wrap cards with light branding on the free tier, and whether a B2B angle (sponsored player pages, branded wrap card templates) makes sense once there's an audience.
