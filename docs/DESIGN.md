# Benchd — Design System

**This document is the source of truth for every pixel in the app.** If a screen
disagrees with this file, the screen is wrong. Read it before writing a view.

---

## 1. What this should feel like

Benchd is where someone looks at their fantasy career and feels something about it.
Six seasons, two championships, one rivalry that will not die. That is a personal
history, and it deserves to be presented the way a good journal or a health app
presents a personal history — calmly, with room to breathe, with the numbers given
weight and space.

**The reference points are Apple Health, Letterboxd, Things, Oak.** Soft gradient
cards, quiet typography, one idea per screen.

**The anti-references are ESPN, DraftKings, Yahoo Fantasy, every sportsbook.** Dense
tables, red and green everywhere, team-color theming, badges competing for attention,
a live ticker pinned to the top. We are not that, and the difference has to be visible
in the first two seconds.

The tone is **editorial, not operational**. We are not a control panel. Nothing here
needs to be actioned. It is something to look at and feel good about.

---

## 2. Principles

These override any individual token. When a rule below conflicts with a component
default, the rule wins.

### One focal point per screen

Every screen has exactly one thing the eye lands on first — usually a single large
number or a single card. Everything else is quieter than it. If two elements compete,
the screen is not finished. A screen with three equally-weighted sections is a screen
with no design.

### Hierarchy through size and weight, not color

Rank information by making it bigger or heavier, not by making it a different color.
A screen should still read correctly in grayscale. Color carries almost no
information in this app — it carries mood.

### The accent is scarce

Light blue appears **at most twice per screen**, and often zero times. It marks:
active state, one key data point, or a brand moment. It is never decoration, never a
default, never used because a thing "needed some color." When in doubt, leave it out
— the calm comes from the restraint.

### White space is a feature

Generous spacing is the single cheapest way this app reads as premium. If a screen
feels tight, the answer is more space, not smaller type. When in doubt, add more.

### Numbers are the payload

The stats are why anyone opens the app. They get the largest type, the most space
around them, and the most care. A stat should feel like a headline, not a table cell.

### Nothing is loud

No bounce, no flash, no pulse, no confetti, no gradient that announces itself. Motion
is gentle. Depth is barely there. The app should feel like it is exhaling.

---

## 3. Palette

All values live in `DesignSystem/Foundation/Palette.swift`. That file is the only
place in the codebase where a raw color value may appear.

### Base

| Token | Hex | Use |
|---|---|---|
| `gradientTop` | `#FFFFFF` | Top of the app background wash |
| `gradientBottom` | `#F4F6F9` | Bottom of the app background wash |
| `surface` | `#FFFFFF` | Cards and raised content |
| `surfaceSecondary` | `#F1F3F6` | Recessed surfaces: inputs, skeletons, grouped rows, neutral pills |
| `divider` | `#E5E8EC` | Hairlines and separators. Never text, never a fill. |

The background is **never a flat color**. Every full screen sits on
`GradientBackground`. A `Color.white` or default `.background(.background)` screen is
a bug.

### Text

| Token | Hex | Use |
|---|---|---|
| `textPrimary` | `#111827` | Headings, body, and every hero number |
| `textSecondary` | `#6B7280` | Supporting copy, descriptions, subtitles |
| `textTertiary` | `#9CA3AF` | Stat labels, metadata, timestamps, placeholders |

Three levels is the whole system. There is no fourth. If something needs to be
quieter than tertiary, it probably should not be on the screen.

### Accent

| Token | Hex | Use |
|---|---|---|
| `accent` | `#7FB2E5` | Fills, strokes, dots, rings, indicators, decorative marks |
| `accentInk` | `#2B6CA3` | Accent applied to **text or icons** that must stay legible |
| `accentTint` | `#EAF3FC` | Pill and badge backgrounds, soft highlight fills |

**Why there are two blues.** `#7FB2E5` on white is roughly 2.2:1 contrast. That is
below the WCAG AA floor for text at any size, so it can never carry a word or a glyph
a user needs to read — only shapes. When the accent has to be *read*, use `accentInk`
(~5.1:1 on white and on `accentTint`). This is not a second accent color; it is the
same accent at a legible weight, and it should be just as scarce.

A soft accent looks premium precisely because it is low-contrast. Do not "fix" it by
darkening `accent` — fix the usage.

### Semantic (restricted)

| Token | Hex | Use |
|---|---|---|
| `positive` | `#5B8C73` | A gain, muted sage |
| `negative` | `#B07C6E` | A loss, muted clay |

These are deliberately desaturated so they read as editorial, not as a betting slip.
**Hard rules:** never as a background fill, never on a hero number, never on more than
two elements per screen, never paired side by side in a table. Prefer conveying
direction with a glyph (`arrow.up` / `arrow.down`) in `textSecondary` and let the
number stay `textPrimary`. Reach for these only when direction genuinely cannot be
read any other way.

This is the palette's most dangerous pair. Misuse here is what turns the app into
the thing we said we would not build.

### Depth

| Token | Value | Use |
|---|---|---|
| `shadow` | `#1F2A37` @ 5–7% | Card shadows. Tinted slate, never pure black. |

### Explicitly banned

- **Dark mode-first treatment.** v1 is a light app. The palette is built around a
  white gradient; a dark inversion would be a different design, not a theme. The app
  is locked to light appearance in `Info.plist`.
- **Pure black backgrounds** (`#000000`). Also pure black text — `textPrimary` is
  `#111827` for a reason.
- **Saturated team colors.** No Chiefs red, no Eagles green, no team-themed surfaces
  or avatar rings. A player page for a Jets WR looks identical to one for a Bills WR.
- **Loud gradients.** No multi-hue ramps, no diagonal rainbow washes, no mesh
  gradients, no animated backgrounds. The only gradient is the near-invisible
  `#FFFFFF → #F4F6F9` wash, plus an optional low-opacity single-hue accent bloom.
- **Red/green sportsbook styling.** No `.red`, no `.green`, no system semantic colors.
  See the restricted pair above.
- **System color literals** of any kind: `Color.blue`, `Color.gray`, `.accentColor`,
  `Color(.systemBackground)`. Everything comes from `Palette`.

---

## 4. Typography

SF Pro — the system font. No custom font files, no third-party type. All roles live
in `DesignSystem/Foundation/Typography.swift`.

The scale is built around one idea: **the display sizes are light and tight, the text
sizes are normal.** A 64pt number at `.light` with negative tracking reads as
editorial. The same number at `.bold` reads as a scoreboard.

### Display — for numbers only

| Role | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| `displayHero` | 64 | Light | −2.0 | The one number a screen is about |
| `displayLarge` | 44 | Light | −1.2 | Hero number in a card, wrap card figures |
| `displayMedium` | 32 | Regular | −0.6 | A stat in a multi-stat row |
| `displaySmall` | 22 | Medium | −0.2 | Inline stat beside a label |

All four are **monospaced digits**, so a counting or updating number never reflows
the layout around it. Never use a display role for words.

### Text

| Role | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| `title` | 28 | Semibold | −0.4 | Screen title. Once per screen. |
| `headline` | 17 | Semibold | 0 | Section heading, card heading |
| `body` | 16 | Regular | 0 | Body copy |
| `callout` | 15 | Regular | 0 | Supporting copy under a heading |
| `caption` | 13 | Regular | 0 | Metadata, timestamps, footnotes |
| `button` | 16 | Semibold | −0.1 | Button labels |

### Stat label

| Role | Size | Weight | Tracking | Case |
|---|---|---|---|---|
| `statLabel` | 11 | Semibold | +1.2 | Uppercase |

The small tracked uppercase label that sits **above** every big number. It is always
`textTertiary`. The label goes above the number, not below — the eye should hit the
number as the payoff, not as the setup.

Apply it with the `.statLabelStyle()` modifier so the tracking and case never get
retyped.

### Rules

- Line height uses SwiftUI defaults. Do not set `.lineSpacing` outside DesignSystem.
- Body copy is limited to a comfortable measure; do not run text the full width of a
  wide card.
- Never call `.font(.system(...))`, `.font(.title)`, or `Font.custom(...)` in a
  feature file. Use a `Typography` role.
- Dynamic Type: display roles are fixed-size by design so hero numbers hold their
  composition. Text roles should be revisited for accessibility sizes before v1
  ships — tracked as a known gap.

---

## 5. Spacing and layout

Base unit is **4**. Everything is a multiple. All values live in
`DesignSystem/Foundation/Spacing.swift`.

| Token | Value |
|---|---|
| `xxs` | 4 |
| `xs` | 8 |
| `sm` | 12 |
| `md` | 16 |
| `lg` | 24 |
| `xl` | 32 |
| `xxl` | 40 |
| `xxxl` | 56 |
| `huge` | 72 |

### Semantic

| Token | Value | Use |
|---|---|---|
| `screen` | 24 | Horizontal padding on every screen |
| `cardPadding` | 24 | Interior padding of a `Card` |
| `sectionGap` | 32 | Between sections |
| `sectionGapLarge` | 40 | Between major blocks, or above a hero |

### Rules

- Screen content is inset `screen` (24) from both edges. No exceptions for "wide"
  content.
- Vertical rhythm: 8 inside a tight group (label→number), 16 between related
  elements, 24 between groups, 32–40 between sections.
- A hero stat gets at least `xxl` (40) of clearance above and below. Crowding the
  focal point defeats the whole design.
- Never write a raw number into `.padding()` or `spacing:` in a feature file.
- **When in doubt, add more white space.** A screen that feels empty is closer to
  right than a screen that feels full.

---

## 6. Shape and depth

### Corner radius

| Token | Value | Use |
|---|---|---|
| `sm` | 12 | Small controls, pills that are not capsules, skeleton blocks |
| `md` | 16 | Buttons, inputs, compact tiles |
| `card` | 20 | Standard card |
| `cardLarge` | 24 | Prominent card |
| `hero` | 28 | Wrap cards and hero surfaces |

**Always `style: .continuous`.** A circular corner next to iOS system chrome reads as
cheap. `RoundedRectangle(cornerRadius:)` without `style: .continuous` is a bug.

### Borders

| Token | Value |
|---|---|
| `hairline` | 0.5 |
| `border` | 1.0 |

Use `divider` at `hairline` for separators and `border` for card outlines. Never a
stroke heavier than 1pt. Never a dark or saturated stroke. Definition comes from the
hairline plus the shadow, not from a visible outline.

### Shadow

| Token | Color | Radius | Y | Use |
|---|---|---|---|---|
| `soft` | shadow @ 5% | 20 | 6 | Standard card |
| `lifted` | shadow @ 7% | 32 | 12 | Hero card, sheet, wrap card |

Shadows are **large, diffuse, and nearly invisible** — the goal is that a card feels
like it is floating a millimetre off the page, not that you can see a shadow. If you
can point at the shadow, it is too strong. Never a tight dark drop shadow. Never an
inner shadow. No `.shadow(radius: 4)` anywhere.

A card is defined by: `surface` fill + continuous radius + hairline `divider` border +
`soft` shadow. All four, every time. The `Card` component handles it.

---

## 7. Motion

All curves live in `DesignSystem/Foundation/Motion.swift`.

| Token | Curve | Use |
|---|---|---|
| `gentle` | spring, response 0.5, damping 0.86 | Default for state changes |
| `soft` | spring, response 0.7, damping 0.92 | Large surfaces, sheets |
| `quick` | spring, response 0.28, damping 0.9 | Button press, toggle |
| `fade` | easeOut 0.28 | Opacity only |
| `countUp` | easeOut 1.1 | Hero number count-up |

### Rules

- **Springs are damped, never bouncy.** Damping is always ≥ 0.85. If a thing
  overshoots visibly, it is wrong.
- **Numbers count up on first appearance.** A hero stat sweeps from 0 to its value
  over ~1.1s with an easeOut curve, so it decelerates into the final number. This is
  the app's signature motion and the one moment of delight we spend. It fires **once**
  per appearance — not on every scroll, not on re-render.
- **Fade and slight scale, never slide.** Content enters with opacity 0→1 and scale
  0.98→1.0. Horizontal or vertical slides read as chrome; we do not use them for
  content.
- **No looping motion** except the loading shimmer. No pulse, no breathing, no
  attention-seeking animation on an idle screen.
- **Respect Reduce Motion.** Every animation in this system checks
  `accessibilityReduceMotion`. Count-ups jump straight to the final value; the shimmer
  becomes a static fill. This is handled inside the components — feature code gets it
  for free.

---

## 8. Components

Everything in `DesignSystem/Components/`. Build screens from these. If a screen needs
something not on this list, add it here first — never inline a one-off style in a
feature file.

| Component | What it is |
|---|---|
| `GradientBackground` | The app's base wash. Every full screen. Optional accent bloom for brand moments. |
| `Card` | Surface + continuous radius + hairline + soft shadow. The default container. |
| `StatBlock` | Uppercase label above a large number, with count-up. The most important component in the app. |
| `SectionHeader` | Section title, optional subtitle, optional trailing action. |
| `PillTag` | Small capsule label. Neutral or accent tone. |
| `PrimaryButton` | The one action on a screen. Ink fill by default; accent tone for brand moments. |
| `SecondaryButton` | Everything else. Surface fill, hairline border. |
| `Avatar` | Circular image or initials fallback. Optional accent ring for active state. |
| `SoftDivider` | Hairline separator with optional inset. |
| `EmptyState` | Quiet centered mark, title, message, optional action. |
| `SkeletonBlock` / `.shimmering()` | Soft loading placeholder. |

`DesignGalleryView` renders every token and component plus a sample composition. It is
the visual regression check — open its preview after changing anything here.

### On the primary button

`PrimaryButton` defaults to an **ink fill with a white label**, not an accent fill.
Two reasons. First, contrast: white on `#7FB2E5` is ~2.2:1 and unreadable. Second, and
more important, a blue button on every screen would spend the accent on the most
routine element in the app and break the scarcity rule. A near-black button is calmer,
more editorial, and leaves blue meaning something.

The `.accent` tone exists for genuine brand moments — the end of onboarding, a wrap
card share action. It pairs the soft accent fill with **ink text**, not white, which
keeps it legible (~9:1). Use it once in a flow, if at all.

---

## 9. Before you ship a screen

- [ ] It sits on `GradientBackground`.
- [ ] There is exactly one focal point.
- [ ] It reads correctly in grayscale.
- [ ] The accent appears twice or fewer.
- [ ] No raw color, font, or spacing value outside `DesignSystem/`.
- [ ] No `List`, no `Form`, no default `.navigationTitle` chrome left unstyled.
- [ ] Every card is a `Card`. Every big number is a `StatBlock`.
- [ ] Corners are `.continuous`.
- [ ] Loading and empty states exist and are designed, not a spinner.
- [ ] Animations respect Reduce Motion.
- [ ] Every view has a `#Preview`, including its loading and empty states.
- [ ] Ask honestly: could this have been produced by someone who never read this
      document? If yes, it is not done.
