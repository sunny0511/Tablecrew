# TableCrew Design System

## Purpose and Scope

This document defines the visual and interaction language for TableCrew across iOS and Android. It exists so that a new designer or engineer can pick up any screen in the product and know, without asking, what color to reach for, what typeface to set, how much space to leave, and how a component should feel when it moves. It is the execution layer beneath `BRAND_GUIDELINES.md` (which defines who we are) and `COPY_GUIDELINES.md` (which defines how we talk). This document defines how we look and how we behave on screen.

Every decision below is made in service of the same design principle stated in `VALUES.md`: **hospitality is a design principle, not a vibe.** A well-designed Table doesn't just look good — it makes a first-time guest feel like someone already pulled out a chair for them. Concretely, that means:

- Warm, food-and-candlelight color language instead of cold, transactional tech-blue.
- Generous whitespace and legible type instead of dense, notification-farm layouts.
- Calm, unhurried motion instead of snappy, gamified micro-interactions that create false urgency.
- Accessibility as a baseline requirement, not a stretch goal, because Grace (58, our empty-nester persona) needs to use this app as comfortably as Alex (31, our organizer persona).

This document must also actively counter the single most damaging brand risk identified in `USER_PERSONAS.md`: the fear that "this is secretly a dating app." Every color, type, and iconography choice below was screened against that risk and chosen partly *because* it does not resemble the dating/social landscape.

---

## 1. Color System

### 1.1 The Competitive Problem We're Solving

Look at the color palettes of Hinge, Bumble, Tinder, Meetup, Partiful, and most Gen-Z-coded social apps: hot pink, magenta, neon purple, coral-on-black, gradient sunsets. That palette family signals *romantic or performative* social energy — swiping, matching, showing off. It is precisely the visual language that triggers Grace's "is this secretly a dating app?" anxiety and reads as youth-coded to Devon (38) and Priya (34), who are not there to perform.

TableCrew's palette needs to signal something entirely different: a shared meal, a lit room, a table that's been set for you. The reference points are hospitality, not dating — think of the warmth of a dinner invitation, not the neon of a nightclub.

### 1.2 Primary Palette

| Token | Name | Hex | Usage |
|---|---|---|---|
| `color.primary.600` | Terracotta | `#C1653A` | Primary buttons, active states, key CTAs ("Reserve a Seat", "Host a Table") |
| `color.primary.500` | Terracotta Light | `#D97F52` | Hover/pressed states, secondary emphasis, chart highlights |
| `color.primary.100` | Terracotta Tint | `#F3DDD0` | Selected chips, subtle highlight backgrounds |
| `color.accent.600` | Amber | `#E0A339` | Secondary accent — RSVP "Going" confirmations, celebratory moments, streak/Crew milestones |
| `color.ink.900` | Ink Charcoal | `#2B241F` | Primary text, headlines, icons on light backgrounds |
| `color.ink.700` | Ink Charcoal Muted | `#524A43` | Secondary text, captions, metadata |
| `color.neutral.0` | Linen Cream | `#FBF6EF` | Primary app background |
| `color.neutral.50` | Card Cream | `#F5EEE3` | Card surfaces, sheet backgrounds |
| `color.neutral.200` | Warm Grey | `#DCD2C4` | Dividers, borders, disabled states |
| `color.success.600` | Sage | `#5E7A5A` | "Going" / confirmed states |
| `color.warning.600` | Gold Ochre | `#B98A1F` | "Waitlisted" / pending states |
| `color.danger.600` | Brick | `#A94A3D` | Errors, "Cancelled" states, destructive actions |

**Why terracotta as primary.** Terracotta and burnt-amber tones sit at the warm end of the color wheel that humans associate with cooked food, baked clay tableware, candlelight, and skin tones across a wide range of complexions — all reference points that reinforce "a table set for you" rather than "an app trying to match you with someone." Critically, terracotta is a color almost no major dating or nightlife-social app uses as a primary, because it reads as *calm* and *earthy* rather than *urgent* or *flirtatious*. That absence is a gift: it lets TableCrew occupy visual territory that is unclaimed in the category and immediately legible as different-in-kind, not just different-in-brand. It is also warm enough to feel inviting to Maya (27, anxious first-timer) without tipping into the neon-playful territory that would alienate Grace or Devon.

**Why ink charcoal instead of black or navy.** Pure black (`#000000`) paired with warm tones reads harsh and print-poster-like; it fights the hospitality feeling. Navy is the default "trustworthy tech" color used by nearly every fintech, productivity, and B2B SaaS product, and using it here would make TableCrew look like a scheduling utility rather than a social one. A warm, slightly brown-black ("ink charcoal," `#2B241F`) keeps full accessible contrast against the cream background while staying inside the same warm family as the rest of the palette — it feels like the color of a well-worn wooden table, not a corporate slide deck.

**Why a cream background instead of pure white or dark mode by default.** Pure white (`#FFFFFF`) backgrounds are the default of nearly every utility and productivity app and read as sterile and clinical — the opposite of a table someone has prepared for you. A soft linen cream (`#FBF6EF`) is warm without being precious, keeps text contrast ratios comfortably in AA/AAA range, and doesn't fatigue the eye during long browsing sessions on Discover. It also photographs well behind screenshots used in App Store listings and marketing, giving the brand a consistent "tablecloth" feel across every touchpoint referenced in `MARKETING.md`.

### 1.3 RSVP / Status Color Mapping

Status colors are one of the most-seen UI elements in the app (every Table card, every Crew roster) so they get a dedicated, restrained mapping rather than ad hoc color choices:

| State | Color token | Rationale |
|---|---|---|
| Going | Sage `#5E7A5A` | Green family reads "confirmed" universally without relying on culturally-specific idiom; sage (not neon green) stays inside the warm, muted palette family |
| Requested | Terracotta Light `#D97F52` | Uses the brand's own primary hue so a pending request feels like "in progress," not "wrong" |
| Waitlisted | Gold Ochre `#B98A1F` | Amber/gold is the most globally-legible "please wait" signal (traffic-light amber), distinct enough from Requested to avoid confusion |
| Not Going / Declined | Warm Grey `#DCD2C4` on Ink text | Neutral, non-punitive — declining a Table should never look like an error or a red flag |
| Cancelled | Brick `#A94A3D` | Reserved exclusively for Table cancellation, so red is never overloaded with "you did something wrong" |

Red is intentionally used nowhere else in the system. Reserving danger-red for actual cancellations (not declines, not form validation of minor fields) keeps it meaningful and prevents the anxious first-timer persona from ever seeing red directed at their own RSVP choice.

### 1.4 Dark Mode

TableCrew ships a dark mode, but it is not the app's default identity — many social-only apps use dark mode as their primary skin because it reads "premium" or "nightlife," which again tilts toward the dating/nightclub aesthetic we are avoiding. Our dark mode instead reads as "candlelit dinner at night," achieved by shifting warmth downward rather than toward cool blue-black:

| Token | Light | Dark |
|---|---|---|
| Background | `#FBF6EF` | `#1E1A16` (warm near-black, not `#000000` or cool slate) |
| Card surface | `#F5EEE3` | `#2A241F` |
| Primary text | `#2B241F` | `#F3ECE0` |
| Terracotta primary | `#C1653A` | `#E08A5C` (lightened ~12% for sufficient contrast on dark) |
| Divider | `#DCD2C4` | `#3A332C` |

**Dark mode contrast, verified (not just asserted):** primary text `#F3ECE0` on dark background `#1E1A16` measures approximately **14.7:1**, comfortably exceeding AAA (7:1) for body text. Terracotta primary `#E08A5C` used as text or an icon against the dark background measures approximately **6.6:1**, exceeding the 4.5:1 AA minimum for normal text and well above the 3:1 minimum for large text/UI elements. These ratios are checked the same way the light-mode ratios in section 6 are checked — as a gating requirement before a dark-mode token ships, not an assumption that "lightened for contrast" is self-verifying.

Dark mode follows the OS-level setting by default (`system` mode) rather than forcing users to opt in — consistent with the "defaults favor user comfort" value — but a manual override is always available in Settings for users like Grace who may prefer to keep light mode regardless of system default (some OS dark-mode defaults are tied to time of day and can be jarring mid-use).

---

## 2. Typography

### 2.1 Recommended Pairing

- **UI / body typeface:** **Inter** (humanist grotesque sans-serif), used for all body copy, buttons, form fields, navigation, and system text.
- **Display / headline typeface:** **Fraunces** (a warm, slightly irregular serif with soft terminals), used for screen titles, Table names when displayed large, onboarding headlines, and empty-state headlines.

**Why this pairing.** Inter is one of the most legible humanist sans-serifs at small sizes on mobile screens, has excellent language coverage (Latin, Cyrillic, Greek, and strong support for extended Latin diacritics used across European languages), and is free and open-source (SIL Open Font License), which matters for a global-first product that cannot assume every user's device has a specific licensed font installed as a fallback. Its humanist warmth (open apertures, slightly rounded terminals) avoids the cold, geometric feel of grotesques like Helvetica or the "tech startup default" feel of a typeface like Roboto used at heavy weight.

Fraunces is a "wonky," low-contrast display serif with warm, almost hand-set character — it was designed explicitly for editorial and hospitality contexts, and at large sizes it evokes the feeling of a handwritten menu or an invitation card rather than a corporate wordmark. Pairing a warm display serif with a clean humanist sans is a well-established pattern in hospitality and food-media branding (menus, restaurant identities) and reinforces the "table" half of the brand name, while Inter keeps the actual task-oriented UI (buttons, RSVP flows, forms) fast and unambiguous to read. Critically, Fraunces is used sparingly — headlines and Table names only — so the app never feels precious or slow to use; the serif carries emotion, the sans carries function.

Both typefaces are available for free via Google Fonts, which matters for build size, licensing simplicity, and consistent rendering across Flutter's cross-platform font-embedding pipeline.

### 2.2 Type Scale

| Token | Typeface | Size / Line height | Weight | Usage |
|---|---|---|---|---|
| `type.display.lg` | Fraunces | 34 / 40 | 500 (Medium) | Onboarding headlines, empty-state headlines |
| `type.display.md` | Fraunces | 26 / 32 | 500 | Table name on Table detail screen |
| `type.heading.lg` | Inter | 22 / 28 | 600 (SemiBold) | Screen titles ("Your Crews", "Discover") |
| `type.heading.md` | Inter | 18 / 24 | 600 | Section headers, card titles |
| `type.body.lg` | Inter | 16 / 24 | 400 (Regular) | Primary body copy, form input text |
| `type.body.md` | Inter | 14 / 20 | 400 | Secondary body copy, list rows |
| `type.caption` | Inter | 12 / 16 | 500 | Timestamps, metadata, RSVP chip labels |
| `type.button` | Inter | 16 / 20 | 600 | All button labels |

### 2.3 Large Text / Accessibility Mode

Because Grace (58) and other users may need larger text without the app feeling like a completely different product, TableCrew respects the OS-level dynamic type / font-scaling setting (Dynamic Type on iOS, font scale on Android) up to 200%, and every screen is designed and tested at three scale steps: 100% (baseline), 130% (common accessibility setting), and 200% (maximum). Layouts use flexible, wrapping containers rather than fixed-height rows so that scaled text never truncates or overlaps. We do not offer an in-app "large text" toggle that duplicates the OS setting — respecting the system setting is both less code to maintain and more familiar to users who've already configured it once for every app on their phone.

Minimum body text size at 100% scale is 16px (`type.body.lg`), one step above the more common 14px default used by many apps, because our older and non-social-media-native personas (Grace, Devon) are a priority segment, not an edge case.

---

## 3. Spacing and Grid

TableCrew uses a **4pt base unit** spacing scale, which is standard across both iOS Human Interface Guidelines and Android Material guidance, ensuring the app feels native on each platform rather than like a cross-platform compromise.

**Implementation note (added 2026-08):** in Flutter, this design system is implemented on top of **Material 3** (`useMaterial3: true`), not as a from-scratch widget system — Material 3's `ColorScheme`, `TextTheme`, and component theming APIs are the mechanism, fully overridden with TableCrew's own tokens (Section 1's terracotta/cream palette, Section 2's typography, this section's 4pt scale) rather than left at Material's defaults. This is why the app doesn't read as "a generic Material app" despite using Material 3 as its underlying engine: every default color, shape, and elevation value is replaced, and only Material's theming plumbing (and its substantial built-in accessibility/RTL support, Section 7) is inherited as-is.

| Token | Value | Usage |
|---|---|---|
| `space.xs` | 4px | Icon-to-label gaps, chip internal padding |
| `space.sm` | 8px | Compact stacking (avatar-to-name) |
| `space.md` | 16px | Standard component padding, gap between form fields |
| `space.lg` | 24px | Card padding, section gaps |
| `space.xl` | 32px | Screen-edge margins, gap between major sections |
| `space.xxl` | 48px | Empty-state vertical rhythm, onboarding breathing room |

**Screen margins:** 24px minimum left/right margin on all screens (`space.xl`), wider than the more common 16px default — this is a deliberate choice to make the app feel less dense and more like a well-set table with room between place settings, rather than a packed feed. Density is the enemy of "unhurried."

**Grid:** content is laid out on a 4-column grid on phones (gutters of 16px) and an 8-column grid on tablets, with a maximum content width of 600px on larger screens/foldables so that Table cards never stretch into illegibly wide single-column layouts.

**Corner radius:** TableCrew uses a consistent 16px corner radius on cards and 12px on buttons and input fields — soft enough to feel approachable (avoiding sharp, "enterprise dashboard" rectangles) without the overly playful, almost circular radii (24px+) used by youth-coded social apps.

---

## 4. Component Library

### 4.1 Buttons

- **Primary button:** Terracotta (`#C1653A`) fill, cream text (`#FBF6EF`), 12px radius, 48px minimum height (exceeds the 44pt/48dp minimum tap target on both platforms). Used for one primary action per screen only (e.g., "Reserve Your Seat," "Send Invite").
- **Secondary button:** Outlined, 1.5px Ink Charcoal border, transparent fill, Ink Charcoal text. Used for lower-emphasis actions ("Not This Time," "View Details").
- **Tertiary / text button:** No border or fill, Terracotta text, used for inline actions ("Edit," "Cancel Table").
- **Destructive button:** Outlined in Brick (`#A94A3D`), fills solid only on final confirmation step (e.g., confirming a Table cancellation), to avoid a red button ever being the first thing a user sees in a flow.

All buttons use a minimum 44x44pt touch target regardless of visual size, and disabled states drop to 40% opacity with no color hue shift (so they remain within the same warm family rather than turning cold grey).

### 4.2 Cards

**Table Card** (used on Discover, "Your Tables," and Crew feeds): Card Cream (`#F5EEE3`) surface on Linen Cream background, 16px radius, subtle 1px Warm Grey border (no drop shadow on light backgrounds — shadows read as "floating tech UI"; a hairline border reads as "placemat on a table"). Contains, top to bottom: host avatar + name, Table name (Fraunces, `type.display.md` scaled down to card context), date/time/location line, headcount indicator ("4 of 6 seats"), and an RSVP status chip anchored bottom-right.

**Crew Card**: A horizontally-scrollable stack of member avatars (max 5 visible, "+N" overflow chip), Crew name in `type.heading.md`, and a subtle "last gathered" timestamp — designed to feel like a photo of people you already know, not a follower-count.

### 4.3 RSVP Status Chips

Small pill-shaped chips (full corner radius, height 24px), colored per the status mapping in section 1.3, always paired with a text label (never color alone — see Accessibility, section 6) — e.g., a small filled circle + "Going" in Sage, or "Waitlisted" in Gold Ochre outline style (outlined rather than filled, to visually de-emphasize a pending/uncertain state relative to a confirmed one).

### 4.4 Avatars

Circular, not square — circles are the universal "person" shape across cultures and avoid any resemblance to ID-card or dating-profile-photo framing (which tend to use square or vertical-rectangle crops reminiscent of swipeable profile cards). Default placeholder avatars (for users without a photo) use a solid Terracotta-family background with the user's initial in cream text — never a generic grey silhouette, which reads as unfinished/anonymous in a product about showing up as yourself. Group/Crew avatars stack with a 2px cream border between overlapping circles to keep individuals visually distinct even when tightly stacked.

### 4.5 Empty States

Every empty state includes: an illustration (see section 5), a Fraunces headline, one sentence of Inter body copy, and — where applicable — a single primary button. Empty states are never left as a blank screen with just a button; per the hospitality value, an empty state is a moment to reassure, not just a call to action. (See `COPY_GUIDELINES.md` section on empty-state copy for exact strings.)

---

## 5. Iconography

TableCrew uses a **custom icon set built on rounded-stroke, 1.5px-weight line icons** (not filled/glyph icons, not the sharp geometric icons common in productivity tools). Rounded stroke caps and joins match the softened, humanist quality of Inter and the 16px card radius, keeping the whole system visually coherent.

Icon subject matter deliberately favors literal, warm objects over abstract tech metaphors: a table-and-chairs glyph for "Table," a small cluster-of-people glyph for "Crew," a compass-rose-style glyph for "Discover" (evoking exploration/serendipity rather than a dating-app "spark" or flame icon, which we explicitly avoid). Icons are single-color (Ink Charcoal or Terracotta depending on state) — never multi-color or gradient-filled, which would read as playful/gamified rather than calm.

---

## 6. Accessibility Standards

TableCrew targets **WCAG 2.1 Level AA as an absolute minimum**, with AAA contrast ratios adopted wherever they don't compromise the warm palette, because accessibility directly serves priority persona Grace and is a direct expression of "hospitality is a design principle."

Concrete standards:

- **Color contrast:** All body text maintains a minimum 4.5:1 contrast ratio against its background (Ink Charcoal `#2B241F` on Linen Cream `#FBF6EF` measures approximately 12.6:1). Large text (18px+ bold or 24px+ regular) maintains at least 3:1. Terracotta primary buttons use cream text, verified at 4.6:1 minimum.
- **Never color-alone:** Every status (RSVP chips, form validation, success/error) is conveyed with an icon or text label in addition to color, for users with color vision deficiencies.
- **Touch targets:** minimum 44x44pt (iOS) / 48x48dp (Android) for every interactive element, with at least 8px spacing between adjacent tappable elements to prevent mis-taps — particularly important for Grace and any user with reduced fine motor precision.
- **Dynamic type support:** up to 200% scaling, tested per section 2.3, with no truncation.
- **Screen reader support:** all icons, avatars, and chips carry semantic labels (e.g., an avatar-only button is labeled "View [Name]'s profile," not "Button"); all custom components (RSVP chips, Table cards) expose proper heading and role semantics for VoiceOver/TalkBack.
- **Motion sensitivity:** all animations respect the OS-level "Reduce Motion" accessibility setting by falling back to instant or cross-fade transitions.
- **Language and reading level:** per `COPY_GUIDELINES.md`, UI copy targets a plain-language reading level (roughly a 6th–8th grade reading level in English) so that translated copy remains simple and non-native English speakers are not excluded.

**Physical venue accessibility (a gap the app-only accessibility standards above do not cover).** Everything above governs whether the *app* is usable by someone with a disability. It says nothing about whether the *Table itself* is usable — a Table is a real, in-person gathering at a real venue, and a wheelchair user or someone with a mobility limitation currently has no way to know, before requesting to join, whether that venue has step-free entry, an accessible restroom, or adequate seating clearance. For a product whose mission is explicitly "anyone, anywhere" (`PRODUCT.md`), this is a genuine inclusion gap, not a nice-to-have: a user who cannot physically enter the venue is functionally excluded from the Table regardless of how accessible the app UI is. Concretely, this design system requires:

- A **venue accessibility field**, optionally filled in by the host when creating or selecting a venue for a Table, covering at minimum: step-free entry (yes/no/unsure), accessible restroom on-site (yes/no/unsure), and free-text notes (e.g., "two steps at the entrance, no ramp" or "accessible entrance is around the side, buzz for staff"). "Unsure" must be a first-class option, not a forced binary — hosts often don't know a venue's accessibility details with certainty, and a forced yes/no would produce unreliable data.
- **Visible surfacing on the Table card and Table detail screen** whenever this information has been provided — a small icon + label (following the same "never color-alone, always icon-plus-text" standard as RSVP chips in section 6) placed near the location/address line, not buried in an expandable "more info" section a guest must know to look for.
- **A Discover filter** so a user who needs step-free access can filter Discover results to Tables at venues marked accessible, the same way Discover already supports interest-based filtering (`FEATURES.md`) — an accessibility need should be a first-class filter, not something a user has to message a host to ask about after already being interested.
- **This is flagged here, not fully specified here, because it requires a data model change this document does not own.** Concretely, this likely requires a `Venue.accessibilityInfo` field (or equivalent) in the schema owned by `DATABASE.md`, and a corresponding Discover query/filter parameter owned by `API_SPEC.md` and `PRD.md`. This section records the design and UX requirement (the field must exist, must default to "unsure" rather than a false negative or false positive, and must be visibly and filterably surfaced); the schema and query implementation is out of scope for this document and should be picked up by whoever owns `DATABASE.md` and `PRD.md`'s Discover requirements.

---

## 7. Right-to-Left (RTL) and Bidirectional Layout

`VALUES.md` §4 states "global-first, not U.S.-first-then-ported" and explicitly names "right-to-left layout support" as part of that commitment. That is a real, non-trivial design system requirement for any market where Arabic, Hebrew, Urdu, or other RTL-script languages are primary — and it is the kind of requirement that is cheap to design in from the start and expensive to retrofit once hundreds of screens assume left-to-right. This section makes it concrete rather than leaving it as a one-line aspiration in a values document.

**What mirrors (flips horizontally in RTL locales):**

- Overall screen layout direction: navigation drawers, back buttons, and forward-progress affordances (e.g., "Next" in onboarding) mirror to the opposite screen edge.
- The 4/8-column grid (section 3) mirrors as a unit — content reading order flows right-to-left, and screen margins (`space.xl`) apply symmetrically so mirroring never requires bespoke per-screen spacing values.
- Iconography with implied directionality: arrows, the onboarding "Next" chevron, the swipe-back affordance, and the Discover compass-rose glyph's directional cues (section 5) all mirror.
- Text alignment: body copy, headlines, and form labels flip from left-aligned to right-aligned.
- Component layout: the Table Card's internal structure (section 4.2) mirrors as a block — host avatar and RSVP chip swap sides — so the card still reads start-to-end correctly in the local script direction.
- Horizontal page transitions (section 8, "Motion and Animation Principles") reverse direction to match the locale's natural forward/back reading direction.

**What does not mirror (a common and costly mistake if missed):**

- **Numerals.** Arabic-indic or other locale-specific numeral systems follow their own script conventions independent of layout direction; headcounts ("4 of 6 seats"), times, and prices are formatted per `COPY_GUIDELINES.md` section 6's locale-aware formatting rule, not manually flipped.
- **Icons that depict a real-world object rather than a direction.** The table-and-chairs glyph, the cluster-of-people Crew glyph, and photographic content (avatars, venue photos) never mirror — flipping a photo or a literal object glyph looks broken, not localized, because it depicts something with a real, non-symmetric orientation in the world.
- **Logo and wordmark.** Per `BRAND_GUIDELINES.md` section 4, the wordmark and icon mark are never mirrored, rotated, or otherwise altered — an RTL layout places the existing, unflipped logo lockup at the (now-mirrored) leading edge of the layout, it does not produce a mirrored version of the mark itself.
- **Charts and status-color mapping.** The RSVP/status color mapping (section 1.3) is a color-plus-label pairing, not a directional element, and is unaffected by RTL; a "Going" chip is Sage in every locale regardless of layout direction.

**Engineering implementation note (owned by `ENGINEERING_GUIDELINES.md`, flagged here as a design requirement):** Flutter's built-in `Directionality` widget and `EdgeInsetsDirectional` / `AlignmentDirectional` primitives should be used throughout instead of hardcoded `left`/`right` padding or alignment values, so that RTL support is a locale flag rather than a parallel set of hand-mirrored screens. Any new component added to the library in section 4 must be verified in both LTR and RTL before being marked done — this is a required row in the component parity audit described in section 10 (Design Tokens and Maintenance), not a separate, optional QA pass.

---

## 8. Motion and Animation Principles

TableCrew's motion language is described in one phrase: **warm and unhurried, never snappy or game-like.** This is a direct, deliberate contrast to the swipe-and-match, confetti-and-haptic-heavy motion language of dating and gamified social apps, whose fast, high-frequency micro-rewards are part of what makes them feel like "engagement machines" rather than hospitable spaces (see `VALUES.md`: "real connection over engagement metrics").

Concrete principles:

- **Easing:** all transitions use an ease-in-out curve with slightly longer durations than typical mobile defaults — 250–350ms for standard screen transitions (vs. the common 150–200ms), 400ms for modal/sheet presentations. Nothing snaps into place instantly; things arrive the way a plate is set down, not the way a notification badge pops.
- **No gamified reward animation:** confirming an RSVP, joining a Crew, or completing onboarding never triggers confetti, badge-unlock animations, or slot-machine-style reveals. A confirmed "Going" status simply and calmly fills in with a soft scale-and-fade (button depresses slightly, chip fades from Terracotta to Sage over 300ms).
- **Loading states:** use a gentle pulsing skeleton in Card Cream tones rather than a spinning wheel — a spinner communicates "wait, something is processing," a soft pulse communicates "we're getting your table ready."
- **Haptics:** used sparingly and only for meaningful confirmations (successfully joining a Table, sending an invite) — a single light-medium impact tap, never a repeated buzz pattern, and never used to punctuate routine navigation.
- **Page transitions:** primarily horizontal slide (forward) / slide-back (dismiss), consistent with each platform's native navigation paradigm, with cross-fade reserved for modal sheets (RSVP confirmation, Crew creation) to differentiate "a new place" from "a moment layered on top of where you are."

---

## 9. Dark Mode Approach (Summary Reference)

See section 1.4 for full token values. Principle in one line: dark mode should feel like the same dinner after the sun goes down, not a different, colder app — every dark-mode token is a warmth-preserving shift of its light-mode counterpart, never a hue rotation into blue-black or pure grayscale.

---

## 10. Design Tokens and Maintenance

TableCrew's design system is maintained as a **single source of truth in Figma**, with token values (color, type, spacing, radius) mirrored into a machine-readable token file (JSON, following the W3C Design Tokens Community Group format) that is synced into the Flutter codebase as a generated `ThemeData` / `ThemeExtension` file.

Workflow:

1. **Figma library:** One shared Figma library file (`TableCrew — Core Design System`) contains all color styles, text styles, spacing variables (using Figma Variables, not hard-coded values), and the component library (buttons, cards, chips, avatars, empty states) documented in this file. Every product Figma file consumes this library rather than duplicating styles locally.
2. **Token export:** Design tokens are exported from Figma Variables via a token-export plugin into `design-tokens.json`, checked into the repository under `design/tokens/`.
3. **Code generation:** A build script (referenced in `ENGINEERING_GUIDELINES.md`) transforms `design-tokens.json` into a generated Dart file (`lib/theme/generated_tokens.dart`) exposing strongly-typed constants (e.g., `TCColors.primary600`, `TCSpacing.md`) consumed by the app's Flutter `ThemeData`. Engineers never hand-type a hex value or magic-number spacing directly into a widget — every visual property is pulled from a token.
4. **Review cadence:** Any change to a token (new color, new spacing value, new type style) requires a design review and a corresponding PR that regenerates the token file — tokens are treated as an API contract between design and engineering, not a casual reference doc.
5. **Component parity audits:** Quarterly, design and engineering jointly audit shipped screens against the Figma library to catch drift (a common failure mode where engineering hard-codes a "close enough" value under deadline pressure). Drift is logged in `TASKS.md` and resolved within the same quarter.

This document (`DESIGN_SYSTEM.md`) is the canonical written record; the Figma library and generated token file are the canonical *executable* records. When the three disagree, this document and the Figma library win, and the generated token file is regenerated to match — never the reverse.
