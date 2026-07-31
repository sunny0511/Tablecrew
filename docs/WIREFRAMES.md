# Wireframes

**Status:** Living document, v1.0. **Owners:** Product, Design jointly. **Related docs:** `SCREEN_SPECIFICATIONS.md`, `DESIGN_SYSTEM.md`.

Low-fidelity layout wireframes for every screen in `docs/SCREEN_SPECIFICATIONS.md` — boxes, labels, and rough regions only, with no typography, color, or spacing detail implied. The point of drawing these before any Flutter work starts is that layout and information-architecture mistakes are cheap to catch here and expensive to catch after a screen is built. Each wireframe is derived directly from that screen's actual "UI Components" field, not invented independently, and each is followed by a short Notes callout naming a real, specific risk worth resolving before implementation — not a restatement of the picture in words.

Read this alongside `docs/SCREEN_SPECIFICATIONS.md` (same screen numbers and names throughout) and `docs/DESIGN_SYSTEM.md` (for the actual visual tokens — color, type, component specs — that these boxes deliberately don't attempt to represent).

## Table of Contents

**Onboarding & Authentication:** [1](#1-splash--launch-screen) · [2](#2-phone-number-entry) · [3](#3-otp-verification) · [4](#4-date-of-birth-entry-age-gate) · [5](#5-profile-setup) · [6](#6-interest-selection) · [7](#7-notification-permission-priming) · [8](#8-identity-verification-tier-2--id--liveness)

**Home & Table Lifecycle:** [9](#9-home-my-tables) · [10](#10-create-table) · [11](#11-venue-picker) · [12](#12-invite--share-sheet) · [13](#13-table-detail) · [14](#14-live-table-screen-day-of-with-duress-control) · [15](#15-table-chat) · [16](#16-waitlist-screen) · [17](#17-post-table-rating)

**Discover:** [18](#18-discover-feed) · [19](#19-discover-filters) · [20](#20-discover-table-preview) · [21](#21-first-time-safety-briefing)

**Crews:** [22](#22-crews-list) · [23](#23-create-crew) · [24](#24-crew-detail) · [25](#25-crew-chat) · [26](#26-recurring-table-schedule-setup)

**Trust & Safety:** [27](#27-report-flow) · [28](#28-block-confirmation) · [29](#29-trusted-contact-setup)

**Payments:** [30](#30-bill-split-setup) · [31](#31-split-request--payment-detail)

**Account & Settings:** [32](#32-profile--me) · [33](#33-settings) · [34](#34-tablecrew-subscription) · [35](#35-notification-center) · [36](#36-data-export--delete-account)

---

## Part 1: Onboarding, Home & Table Lifecycle

---

### 1. Splash / Launch Screen

```
┌──────────────────────────────────┐
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│           T a b l e C r e w       │
│             (wordmark only)       │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
└──────────────────────────────────┘
 no buttons, no body copy — static

— Key alternate state (cold start > 800ms) —
┌──────────────────────────────────┐
│                                    │
│           T a b l e C r e w       │
│         [▓▓▓▓▓▓▓▓▓▓░░░░░░░░]      │
│          (thin skeleton bar)      │
│                                    │
└──────────────────────────────────┘
```

**Notes:** Everything here is conditional on timing (skeleton bar only appears past 800ms, hard 5s timeout), so the "default" state a reviewer sees in a static mock is actually the *rare* state — make sure design QA checks the truly-empty 0–800ms state, not just this bar. Also worth flagging: this screen has zero interactive elements, so any reviewer instinct to "add a logo tap" or a version label should be resisted — it's intentionally a pure router.

---

### 2. Phone Number Entry

```
┌──────────────────────────────────┐
│  What's your number?              │  Fraunces headline
│  We'll text you a code...         │  Inter body (1 line)
│                                    │
│  ┌────────┐ ┌───────────────────┐ │
│  │ [US ▾] │ │ (___) ___-____    │ │  country selector + phone field
│  └────────┘ └───────────────────┘ │
│                                    │
│                                    │
│  ┌──────────────────────────────┐ │
│  │        Send Code             │ │  Terracotta primary (disabled
│  └──────────────────────────────┘ │  until plausible number)
│                                    │
│  By continuing you agree to       │
│  Terms & Privacy                  │  small-print legal links
│                                    │
│  Have an issue?                   │  support link
└──────────────────────────────────┘
```

**Notes:** The country-code selector and phone field sit side-by-side as two separate tap targets — worth confirming the native picker (required for VoiceOver) doesn't visually crowd the phone field on narrow (iPhone SE-class) widths. Also flag the rate-limit/cooldown state (5 attempts/15 min): it replaces the button label with a timer rather than disabling silently, so leave room in the button's box for that text swap without reflowing the layout above it.

---

### 3. OTP Verification

```
┌──────────────────────────────────┐
│  Enter the code we sent to        │  Fraunces headline (masked #)
│  •• ••34                          │
│                                    │
│   ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐  │
│   │ 1│ │ 2│ │ 3│ │ 4│ │ 5│ │ 6│  │  6-digit segmented input
│   └──┘ └──┘ └──┘ └──┘ └──┘ └──┘  │  (auto-advance, auto-submit)
│                                    │
│  ┌──────────────────────────────┐ │
│  │           Verify             │ │  Terracotta primary
│  └──────────────────────────────┘ │  (auto-triggers on 6th digit)
│                                    │
│         Resend code (0:24)        │  countdown → tappable link
│                                    │
│         Edit number               │  back to screen 2
└──────────────────────────────────┘
```

**Notes:** Six visually-separate boxes must be exposed as *one* accessible field, not six — a naive implementation of "segmented input" tends to ship six unlabeled a11y nodes, which is explicitly called out as wrong in the spec. Also note the "Verify" button becomes mostly redundant once auto-submit fires on digit 6 — worth confirming with design whether it should visually de-emphasize once autofill/auto-advance is expected to be the common path.

---

### 4. Date of Birth Entry (Age Gate)

```
┌──────────────────────────────────┐
│  When's your birthday?            │  Fraunces headline
│  This determines eligibility and  │  Inter body — never public
│  is never shown on your profile  │
│                                    │
│      ┌──────┬──────┬──────┐      │
│      │ MM ▾ │ DD ▾ │ YYYY▾│      │  native DOB picker (wheels)
│      └──────┴──────┴──────┘      │
│                                    │
│                                    │
│                                    │
│  ┌──────────────────────────────┐ │
│  │          Continue            │ │  Terracotta primary
│  └──────────────────────────────┘ │  (disabled until complete)
└──────────────────────────────────┘

— Key alternate state (computed age < 18, hard stop) —
┌──────────────────────────────────┐
│                                    │
│      You must be 18+ to use       │  plain, non-alarming copy
│      TableCrew                    │  (no red error styling —
│                                    │   policy boundary, not error)
│  ┌──────────────────────────────┐ │
│  │      Delete my account       │ │  only two exits, no bypass
│  └──────────────────────────────┘ │
│  ┌──────────────────────────────┐ │
│  │         Sign out             │ │
│  └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Notes:** The hard-stop screen is a genuinely different layout (no headline-body-single-CTA pattern — it's a dead end with exactly two low-emphasis exits and zero path back into the product), so it shouldn't be built by reskinning the "Continue" screen — flag this to design as its own template. Also note the DOB check is server-round-tripped (not a pure client gate), so "Continue" needs an inline loading treatment even though this looks like a simple three-wheel picker.

---

### 5. Profile Setup

```
┌──────────────────────────────────┐
│  Let's set up your profile        │  Fraunces headline
│                                    │
│        ┌──────────────┐          │
│        │  ┊  photo  ┊  │          │  photo picker (required)
│        │  ┊ (camera) ┊ │          │  dashed border if empty
│        └──────────────┘          │
│                                    │
│  First name                       │
│  ┌────────────────────────────┐  │
│  │                            │  │  required, 1–30 chars
│  └────────────────────────────┘  │
│  Last initial (optional)          │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  └────────────────────────────┘  │
│  Bio (optional)             0/140│
│  ┌────────────────────────────┐  │
│  │                            │  │  140-char counter
│  └────────────────────────────┘  │
│  ┌──────────────────────────────┐ │
│  │          Continue            │ │
│  └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Notes:** Photo is the only *hard-required* field (Table Cards never render a default avatar), yet it sits visually equal-weight with two optional text fields below it — consider whether the photo tile needs a stronger required-field visual cue than the text fields get, since a user scanning quickly could treat all four fields as similarly optional. Also, "Continue" stays disabled until the photo *upload confirms server-side* even when offline — make sure the disabled-button state has room for that inline explanation rather than just looking broken.

---

### 6. Interest Selection

```
┌──────────────────────────────────┐
│  What kind of Tables are you      │  Fraunces headline
│  into?                            │
│  Pick at least 3 — change anytime │  Inter body
│                                    │
│  [Coffee] [Lunch] [Dinner]        │
│  [Board Games] [Hiking]           │  wrapping chip grid
│  [Founder Dinners] [Mentorship]   │  (filled = selected)
│  [+ more...]                      │
│                                    │
│           2 selected              │  live counter
│                                    │
│  ┌──────────────────────────────┐ │
│  │          Continue            │ │  disabled until 3 selected
│  └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Notes:** The chip grid has no visible scroll affordance in this sketch but the taxonomy list is open-ended ("Coffee, Lunch, Dinner, Founder Dinners, Board Games, Hiking, Mentorship, etc.") — confirm with design whether this screen scrolls internally or the grid soft-wraps within a fixed viewport, since that materially changes whether "Continue" is always visible or gets pushed off-screen on smaller devices.

---

### 7. Notification Permission Priming

```
┌──────────────────────────────────┐
│                                    │
│         ┌──────────────┐         │
│         │   📱  💬       │         │  illustration: phone +
│         │  (friendly,   │         │  friendly notif bubble
│         │  not alarming)│         │  (decorative, no red badge)
│         └──────────────┘         │
│                                    │
│      Don't miss your Table         │  Fraunces headline
│  Invites, RSVP/chat updates, and  │  Inter body (3 categories)
│  day-of reminders.                │
│                                    │
│  ┌──────────────────────────────┐ │
│  │  Turn on notifications       │ │  Terracotta primary
│  └──────────────────────────────┘ │  → triggers OS dialog
│                                    │
│            Not now                │  text-only secondary
└──────────────────────────────────┘
```

**Notes:** Exactly one primary action plus one plain-text secondary link — the spec is explicit that "Not now" must never become a second full-weight button, so this is worth a specific design-review checkpoint since text-link-vs-button drift is an easy default-component mistake. No granular per-category toggles belong on this screen (that's a Settings concern) — resist the urge to add checkboxes for the three categories mentioned in the body copy.

---

### 8. Identity Verification (Tier 2 — ID + Liveness)

```
┌──────────────────────────────────┐
│  Let's verify it's really you     │  Fraunces headline
│  This confirms your identity so   │
│  Discover stays real — it is not  │  explicit non-background-
│  a background check.              │  check disclaimer
│  Processed by Persona; never on  │
│  your public profile.             │
│                                    │
│  ┌──────────────────────────────┐ │
│  │      Start verification      │ │  → launches Persona SDK
│  └──────────────────────────────┘ │
│                                    │
│  ▾ Why do we ask?                 │  expandable disclosure
│                                    │
└──────────────────────────────────┘

— Key alternate state (post-capture, awaiting result) —
┌──────────────────────────────────┐
│  Let's verify it's really you     │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │ │  full-card skeleton pulse
│  │   Verifying... usually       │ │  (button is now gone —
│  │   under a minute             │ │   replaced by status card)
│  └──────────────────────────────┘ │
│                                    │
│  ▾ Why do we ask?                 │
└──────────────────────────────────┘
```

**Notes:** The distinction between "identity verification" and "background check" is a legal line, not a copy preference — flag for review that the disclaimer text must stay above the fold and not get pushed down by the "Why do we ask?" disclosure expanding. Also worth confirming: the flow supports backgrounding (result can arrive later as a push notification), so the "Verifying..." card state shown here needs a defined re-entry layout for when the user returns to the app mid-verification rather than assuming they'll always watch it resolve live.

---

### 9. Home (My Tables)

```
┌──────────────────────────────────┐
│  [ My Tables ]   My Crews         │  segmented control (top)
│ ────────────────────────────────  │
│  ┌────────────────────────────┐  │
│  │ (o) Dinner @ Luna's         │  │  Table Card: avatar stack,
│  │     Sat 7:00pm  [Going]     │  │  venue/date, RSVP chip
│  ├────────────────────────────┤  │
│  │ (o) Coffee @ Ritual         │  │
│  │     Tomorrow 9am [Waitlist] │  │
│  ├────────────────────────────┤  │
│  │ (o) Hiking @ Trailhead      │  │
│  │     Last wknd  [Rate it! ▸] │  │  Happened-unrated nudge
│  └────────────────────────────┘  │
│              ⋮ scrollable ⋮       │
│                                    │
│                          ┌──────┐ │
│                          │  +   │ │  FAB "Create a Table"
│                          └──────┘ │  pinned bottom, one primary
└──────────────────────────────────┘

— Empty state (zero Tables) —
┌──────────────────────────────────┐
│  [ My Tables ]   My Crews         │
│ ────────────────────────────────  │
│                                    │
│          (illustration)           │
│    Your first Table starts here   │  Fraunces headline
│  Create a Table or find one on    │
│  Discover.                        │
│                                    │
│  ┌──────────────────────────────┐ │
│  │        Create a Table        │ │  same button as FAB,
│  └──────────────────────────────┘ │  not a duplicate control
└──────────────────────────────────┘
```

**Notes:** The FAB and the empty-state button are meant to be *the same control*, not two — a common implementation slip is to build the empty-state CTA as a separate component that drifts in label/behavior from the FAB over time. Also, the sort order (soonest-upcoming → unrated-Happened nudge → future → Cancelled-last) means a single list can mix quite different card "modes" (RSVP chip vs. rating nudge vs. muted Cancelled) — worth checking those visual treatments don't collide or look like the same affordance when scanned quickly.

---

### 10. Create Table

```
┌──────────────────────────────────┐
│  Plan a Table                     │  Fraunces headline
│                                    │
│  [Coffee][Lunch][Dinner]...       │  activity tag (single-select)
│                                    │
│  Venue                            │
│  ┌────────────────────────────┐  │
│  │ 📍 Choose a venue          │  │  → Venue Picker
│  └────────────────────────────┘  │
│  Date          Time               │
│  ┌───────────┐ ┌───────────────┐ │
│  │ Sat, Aug 2│ │  7:00 PM      │ │
│  └───────────┘ └───────────────┘ │
│  How many?                        │
│  2 ─────[■■■■]────────────── 8   │  stepper, highlighted band
│         value: 5                  │  = activity-recommended range
│                                    │
│  Visibility                       │
│  (Crew-only) (Open) (Discover)    │  3-way toggle + inline copy
│                                    │
│  ☐ Repeat weekly/monthly          │
│  ┌──────────────────────────────┐ │
│  │        Create Table          │ │
│  └──────────────────────────────┘ │
└──────────────────────────────────┘

— Key alternate state (activity changes the stepper default) —
  Coffee/Mentorship:  2 ──[■]───────────── 8   (starts 3, band 2–4)
  Lunch:              2 ────[■■]────────── 8   (starts 4, band 3–5)
  Dinner/Founder:     2 ──────[■■■]─────── 8   (starts 5, band 4–6)
  Board Games/Hiking: 2 ────────[■■■■■]─── 8   (starts 6, band 4–8)
  (absolute bounds always hard-clamped 2–8 regardless of activity)
```

**Notes:** This is the screen most likely to get a generic "min/max slider" component that ignores the activity-dependent default — the highlighted recommended band must visibly move/resize when the activity tag changes, and QA should specifically re-select a different activity after adjusting headcount to confirm the default doesn't silently reset or fail to update. Also flag the 3-way visibility toggle: a typical segmented control gives visual priority to the first or selected option, but Crew-only/Open/Discover carry materially different trust and Tier-2-verification consequences and need equal visual weight regardless of which is selected.

---

### 11. Venue Picker

```
┌──────────────────────────────────┐
│  ┌────────────────────────────┐  │
│  │ 🔍 Search venues...        │  │  live-as-you-type search
│  └────────────────────────────┘  │
│  📍 Use current location          │
│  ┌────────────────────────────┐  │
│  │      (map preview,         │  │  embedded map, pins for
│  │       pins shown)          │  │  currently visible results
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ ☕ Ritual Coffee            │  │
│  │    Mission St · 0.2mi      │  │  results list (name,
│  ├────────────────────────────┤  │  neighborhood, category)
│  │ ☕ Sightglass                │  │
│  │    SOMA · 0.6mi            │  │
│  ├────────────────────────────┤  │
│  │  Can't find it? Add        │  │  manual-entry fallback,
│  │  manually                   │  │  always at list bottom
│  └────────────────────────────┘  │
└──────────────────────────────────┘

— Empty state (no results) —
┌──────────────────────────────────┐
│  ┌────────────────────────────┐  │
│  │ 🔍 xyzzy venue             │  │
│  └────────────────────────────┘  │
│          (illustration)           │
│         No spots found            │  Fraunces headline
│  Try a different search, or add   │
│  the venue yourself.              │
│  ┌──────────────────────────────┐ │
│  │       Add this venue         │ │  manual-entry IS the
│  └──────────────────────────────┘ │  primary action here
└──────────────────────────────────┘
```

**Notes:** This is the one empty state in the whole spec where the "primary button" is a fallback data-entry form rather than a retry/back action — make sure whoever builds the generic empty-state component doesn't hardcode "retry search" as the only supported empty-state button behavior. Also worth checking: the map preview is marked decorative/supplementary (screen readers should never be required to interact with it), so its box shouldn't be laid out in a way that visually implies it's the primary way to pick a venue over the list.

---

### 12. Invite & Share Sheet

```
— Default: Crew-only Table —
┌──────────────────────────────────┐
│  Invite your Crew                 │  Fraunces headline
│                                    │
│  ☑ Priya                          │
│  ☑ Marco                          │  multi-select Crew list
│  ☐ Deja                           │  (checkboxes)
│  ☐ Wren                           │
│                                    │
│  Only 3 seats left                │  inline seat-limit note
│  ┌──────────────────────────────┐ │
│  │        Send invites          │ │
│  └──────────────────────────────┘ │
└──────────────────────────────────┘

— Key alternate state: Open-visibility Table —
┌──────────────────────────────────┐
│  Share this Table                 │  different headline
│                                    │
│  ┌────────────────────────────┐  │
│  │  🔗  Copy link              │  │  link-first, no crew list
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  ↗  Share via...            │  │  → native OS share sheet
│  └────────────────────────────┘  │
│                                    │
│        3 of 6 seats filled        │  live headcount readout
└──────────────────────────────────┘
```

**Notes:** This single spec covers three quite different visibility states (Crew-only / Open / Discover-listed), and the Discover variant adds yet another element — an informational "already visible on Discover" card sitting above the same link tools — so this screen can't be built as one static layout with a text swap; treat it as three distinct content configurations sharing a shell. Also confirm the Crew multi-select correctly disables/blocks selection past remaining open seats with an inline note rather than allowing a silent over-invite that fails later at submission.

---

### 13. Table Detail

```
┌──────────────────────────────────┐
│  ┌────────────────────────────┐  │
│  │   (venue photo)             │  │  header block: venue,
│  │  Luna's — Sat 7:00pm        │  │  date/time, lifecycle
│  │  [Filling]                  │  │  state (distinct from
│  └────────────────────────────┘  │  RSVP chips below)
│  ┌────────────────────────────┐  │
│  │ (o) Priya      [Going]      │  │
│  │ (o) Marco      [Requested]  │  │  attendee list + RSVP
│  │ (o) You        [Going]      │  │  status chips
│  │ (o) Deja       [Waitlisted] │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ 💬 "see you all there!"  •3 │  │  chat preview + unread
│  └────────────────────────────┘  │
│  ┌──────────────────────────────┐ │
│  │        Manage Table          │ │  contextual primary
│  └──────────────────────────────┘ │  (label varies by role/state)
│                              [⋮] │  host overflow menu
└──────────────────────────────────┘

— Empty state (zero attendees, just created) —
┌──────────────────────────────────┐
│  ┌────────────────────────────┐  │
│  │  Luna's — Sat 7:00pm         │  │
│  │  [Proposed]                  │  │
│  └────────────────────────────┘  │
│          (illustration)           │
│       Nobody's joined yet         │  replaces attendee list
│  Share this Table to fill it up.  │
│  ┌──────────────────────────────┐ │
│  │      Share this Table        │ │  → reopens Invite sheet
│  └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Notes:** The lifecycle-state indicator (Proposed/Filling/Confirmed/...) and the per-attendee RSVP chips use overlapping color language (both draw from the same Sage/Terracotta/Gold Ochre/Warm Grey/Brick palette) but mean different things — a reviewer should specifically check that the header chip and row chips are visually distinguishable as two different systems, not read as "two attendees have the same status as the Table." Also, report/block access is per-attendee-row (not buried in a global menu) — make sure that overflow doesn't get merged into the single host overflow menu shown in the corner, since the spec treats them as separate, both always-reachable affordances.

---

### 14. Live Table Screen (day-of, with duress control)

```
┌──────────────────────────────────┐
│ [⚠ Safety]      Luna's — Directions│  safety icon: fixed position,
│ ────────────────────────────────  │  outside scroll, ALWAYS first
│  (o)here (o)here (o)on-the-way   │  attendee strip (here/on the
│  (o)?     (o)?                   │  way / unknown-neutral)
│                                    │
│  ┌────────────────────────────┐  │
│  │  💬 Table Chat          ▸   │  │  chat tab/panel entry
│  └────────────────────────────┘  │
│                                    │
│  [Mark Table as started]          │  host-only day-of controls
│  [End Table early]                │
└──────────────────────────────────┘

— Key alternate state: screen just opened, data not yet hydrated —
┌──────────────────────────────────┐
│ [⚠ Safety]   ▓▓▓▓▓▓▓▓▓ (skeleton) │  safety button is ALREADY
│ ────────────────────────────────  │  interactive here — never
│  ▓▓▓ ▓▓▓ ▓▓▓ (attendee skeleton)  │  waits behind data loading
│                                    │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓             │
└──────────────────────────────────┘

  Tapping [⚠ Safety] →
  ┌──────────────────────────────┐
  │   Are you OK?                 │
  │  ┌──────────────────────────┐│
  │  │   Leave this Table       ││  1 tap, no confirmation
  │  └──────────────────────────┘│
  │  ┌──────────────────────────┐│
  │  │   I need help             ││  1 tap, no confirmation
  │  └──────────────────────────┘│  → duress signal
  └──────────────────────────────┘
```

**Notes:** This is the single highest-stakes layout in the whole document — the spec is explicit that no future redesign may move the safety affordance behind a menu, add a confirmation step, or delay its render behind data loading, so the wireframe above deliberately shows it rendering even while every other region is still a skeleton. A reviewer should also confirm the "Are you OK?" sheet's two options are the very first focusable elements when it opens (before any other sheet chrome), and that the venue-header/"Directions" and safety-icon don't visually compete for the same top-corner space at narrow widths, since the spec locates the safety control "e.g., top corner" without pinning an exact side.

---

### 15. Table Chat

```
┌──────────────────────────────────┐
│  ← Table Chat                     │
│ ────────────────────────────────  │
│         Priya confirmed           │  system message (neutral,
│ ────────────────────────────────  │  visually distinct style)
│  (o) Marco                        │
│      running 5 min late!          │  messages from others
│                                    │  (avatar + name)
│                          You  (o) │
│           on my way, no rush      │  own messages
│                                    │
│              ⋮ scrollable ⋮        │
│                     [Jump to latest]│  shown only when scrolled up
│  ┌────────────────────────┐ ┌───┐ │
│  │ Type a message...      │ │ ➤ │ │  composer + send button
│  └────────────────────────┘ └───┘ │
└──────────────────────────────────┘
```

**Notes:** System messages (lifecycle events like "Table is now full") must read as clearly non-conversational at a glance — worth checking they don't get styled close enough to a regular message bubble that a user mistakes an automated notice for something a person said. Report/block access here is via long-press on a message rather than a visible row control, which is easy to miss in a design review since long-press affordances aren't self-evident from a static wireframe or screenshot.

---

### 16. Waitlist Screen

```
┌──────────────────────────────────┐
│  You're #2 in line for            │  Fraunces headline
│  Priya's Dinner                   │
│                                    │
│  You'll be promoted automatically │
│  if a seat opens up before the    │  Inter body
│  Table starts.                    │
│                                    │
│         ┌──────────┐              │
│         │    #2     │             │  position indicator
│         └──────────┘              │  (not a full user list)
│                                    │
│         [Waitlisted]              │  status chip
│                                    │
│  ┌──────────────────────────────┐ │
│  │       Leave Waitlist          │ │  secondary weight —
│  └──────────────────────────────┘ │  deliberately not Terracotta
└──────────────────────────────────┘

— Key alternate state (Table cancelled while waiting) —
┌──────────────────────────────────┐
│          (illustration)           │
│      This Table was cancelled     │  matches Table Detail's own
│                                    │  Cancelled-state treatment
│  ┌──────────────────────────────┐ │
│  │        Back to Home          │ │
│  └──────────────────────────────┘ │
└──────────────────────────────────┘
```

**Notes:** "Leave Waitlist" is intentionally styled at lower visual weight than a typical primary button — flag this explicitly to whoever builds it, since a default button component library will often make the only button on a screen the primary/full-weight style by default, which would contradict the spec's intent of not encouraging departure. The position number must always show a real number, never a vague "you're on the waitlist" — worth a specific QA check that the loading/skeleton state doesn't silently regress to that vaguer copy while position data is fetching.

---

### 17. Post-Table Rating

```
┌──────────────────────────────────┐
│  How was your Table?              │  Fraunces headline
│                                    │
│      ★  ★  ★  ★  ★                │  1–5 star/emoji-face rating
│      1  2  3  4  5                │  (required)
│                                    │
│  Add a comment (optional)          │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  └────────────────────────────┘  │
│  Great to meet:                   │
│  [Priya] [Marco] [Deja]           │  optional positive-only tags
│                                    │
│  ┌──────────────────────────────┐ │
│  │           Submit             │ │
│  └──────────────────────────────┘ │
│                                    │
│  Something felt off?              │  visually separated,
│  Report a concern                 │  lower-emphasis link
└──────────────────────────────────┘
```

**Notes:** The "Report a concern" link must stay fully independent of the star-rating flow — it needs no rating selected first, and its touch target/contrast must stay accessible despite being deliberately lower-emphasis, so it shouldn't be implemented as a literal disabled-looking or hard-to-tap link. Also worth flagging: "great to meet" tags are explicitly positive-only (no negative per-person rating is exposed here at all) — a generic per-attendee rating component could easily be mis-reused from elsewhere in the app with a negative option still wired in, which the spec explicitly rules out to avoid enabling harassment via the rating mechanism.

---

## Part 2: Discover, Crews, Trust & Safety, Payments, Account & Settings

---

### 18. Discover Feed

```
┌─────────────────────────────┐
│ [Search / Filter bar______]▼│  <- opens Discover Filters
├─────────────────────────────┤
│ New to Discover? Read our   │  <- dismissible safety banner
│ safety basics          [x]  │  -> First-Time Safety Briefing
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ [Tag] Dinner   Sat 7pm  │ │
│ │ ~1.2mi away             │ │
│ │ [====------] 3 of 5     │ │
│ │ (H) Host name  ✓        │ │
│ │ (a)(a)(a)(a)(a)+2  [Going]│ │  <- RSVP status chip
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ [Tag] Coffee   Sun 9am  │ │
│ │ ~0.4mi away             │ │
│ │ [==--------] 1 of 4     │ │
│ │ (H) Host name  ✓        │ │
│ │ (a)(a)          [Requested]│
│ └─────────────────────────┘ │
│  ... more cards, scroll ... │
├─────────────────────────────┤
│ [Home][Discover][Crews][Me] │
└─────────────────────────────┘

— Empty state —
┌─────────────────────────────┐
│ [Search / Filter bar______]▼│
├─────────────────────────────┤
│        (illustration)       │
│   "No Tables nearby yet"    │
│  Try widening your search   │
│  or check back soon.        │
│  [   Widen your search   ]  │
└─────────────────────────────┘
```

**Notes:** The RSVP status chip (Going/Requested/Waitlisted) is the one element that changes per-card and must stay legibly distinct from the headcount progress bar right above it — the two are easy to visually conflate if the chip and the bar share a color family. The dismissible safety banner needs a treatment that doesn't compete with the card stack for attention on first load, but its dismissal state also has to persist correctly (it must not reappear every session once dismissed). Watch that six skeleton cards match this card's four-part layout exactly on load, or the transition from skeleton to real content will visibly reflow.

---

### 19. Discover Filters

```
┌─────────────────────────────┐
│ < Filters            Reset  │
├─────────────────────────────┤
│ Radius                      │
│ [----o----------] 12 km     │
├─────────────────────────────┤
│ Activity type                │
│ (Coffee)(Lunch)(Dinner)     │
│ (Founder-dinners)(Boards)   │
│ (Hiking)(Mentorship)        │
├─────────────────────────────┤
│ Interests                    │
│ (Tag)(Tag)(Tag)(Tag)...     │
├─────────────────────────────┤
│ Headcount   2 ──o───o── 8   │
│  (auto-set 4-6 for Dinner)  │
├─────────────────────────────┤
│ Date / time window          │
│ [ pick date/time________ ]  │
├─────────────────────────────┤
│  ~14 results with these     │  <- live skeleton-pulse count
│  filters                     │
│ [     Apply Filters      ]  │
└─────────────────────────────┘
```

**Notes:** The activity-dependent headcount default (Dinner -> 4-6, Coffee -> 2-4) needs a visible "this changed automatically" cue on the slider handles when a single activity is picked, otherwise a user editing headcount by hand won't notice the range silently jumped underneath them when they later toggle activity type. The live result-count line sits directly above the primary button and must handle three states cleanly in the same slot: a number, a skeleton pulse, and the offline/zero-result message — stacking all three as alternates of one region rather than three different UI pieces will keep this simple.

---

### 20. Discover Table Preview

```
┌─────────────────────────────┐
│ < Back                      │
├─────────────────────────────┤
│ [Tag] Dinner                │
│ Sat, Jul 4, 7:00pm          │
│ ~1.2mi away (approx.)       │
│ [========--] 3 of 5 going   │
├─────────────────────────────┤
│ Host                        │
│ (H) Host Name  ✓  [flag]⚑  │  <- report/flag icon, 2-tap safety req
│ "short bio snippet..."      │
├─────────────────────────────┤
│ Attendees                   │
│ (a)(a)(a)(a)(a) +2          │
├─────────────────────────────┤
│ [RSVP status chip if any]   │
│                              │
│ [   Request to Join      ]  │  <- or "Requested"/"Withdraw"/
│                              │     "Join Waitlist"
└─────────────────────────────┘

— Key alternate state (Table gone) —
┌─────────────────────────────┐
│        (illustration)       │
│  "This Table is no longer   │
│      available"             │
│  It looks like this one was │
│  cancelled or filled up.    │
│  [   Back to Discover    ]  │
└─────────────────────────────┘
```

**Notes:** The flag/report icon next to the host's name is doing safety-critical work (2-tap reachability) and must not be visually mistaken for a generic overflow/kebab menu — it needs its own consistent glyph across every screen that repeats this pattern (Crew Detail roster, Crew Chat, Live Table roster). The primary button has four possible label/state variants (Request to Join / Requested / Withdraw / Join Waitlist) that must occupy the same layout slot without the screen jumping — worth mocking all four states side by side before build to confirm consistent sizing.

---

### 21. First-Time Safety Briefing

```
┌─────────────────────────────┐
│        (illustration)       │
├─────────────────────────────┤
│  Verification basics        │
│  One sentence explaining    │
│  how verification works.    │
├─────────────────────────────┤
│  Meeting in public places   │
│  One sentence on early      │
│  Tables & public venues.    │
├─────────────────────────────┤
│  Share your live location   │
│  One sentence on trusted    │
│  contact feature.            │
│  [Set up a trusted contact] │
├─────────────────────────────┤
│  Reporting & blocking        │
│  Always two taps away.      │
├─────────────────────────────┤
│  Learn more about T&S       │  <- text link
├─────────────────────────────┤
│ [      Got it, continue   ] │  <- fixed at bottom, always reachable
└─────────────────────────────┘
```

**Notes:** The spec explicitly requires the "Continue" button be reachable without forcing the user to scroll through every section first — this is a scroll-list, not a swipe-gated carousel, so the fixed bottom button must stay visually anchored (not just "eventually scrollable to") across all four sections shown here. The "Set up a trusted contact" secondary link needs a return path back to this exact scroll position/section after Screen 29, otherwise the user loses their place in the briefing.

---

### 22. Crews List

```
┌─────────────────────────────┐
│ Crews          [+Create Crew]│
├─────────────────────────────┤
│ [search field, if >8 crews] │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │(a)(a)(a)(a)(a)+2 Crew A │ │
│ │ Table proposed for Sat  │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │(a)(a)(a)     Crew B     │ │
│ │ Table happened 3d ago   │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │(a)(a)         Crew C    │ │
│ │ No Tables yet           │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ [Home][Discover][Crews][Me] │
└─────────────────────────────┘

— Empty state —
┌─────────────────────────────┐
│        (illustration)       │
│      "No Crews yet"         │
│  Crews are your people...   │
│  [     Create Crew       ]  │
└─────────────────────────────┘
```

**Notes:** The whole Crew Card must be one tap target per the a11y note (not just the name text) — worth flagging explicitly to whoever builds this since a common implementation mistake is making only the title line tappable. The search field is conditional (>8 crews) rather than always present, so the layout needs to gracefully absorb/collapse that row rather than leaving dead space for the common case of a handful of Crews.

---

### 23. Create Crew

```
┌─────────────────────────────┐
│ < Cancel        Create Crew │
├─────────────────────────────┤
│ [ (photo picker circle) ]   │
├─────────────────────────────┤
│ Crew name                   │
│ [_________________________] │
├─────────────────────────────┤
│ Add members                 │
│ [ search connections_____ ] │
│  - Name  ✓   [+ Add]        │
│  - Name  ✓   [+ Add]        │
│  - Name       [+ Add]        │
├─────────────────────────────┤
│ Selected: (chip)(chip)(chip)│
├─────────────────────────────┤
│ [     Create Crew        ]  │  <- disabled until valid
└─────────────────────────────┘
```

**Notes:** "Create Crew" stays disabled until both a name (1-40 chars) and at least one member are set — the disabled-vs-enabled visual states should be unmistakable since this is the only gate on the screen. The back/cancel action needs a "Discard this Crew?" confirmation only when a field has been touched, so the wireframe's Cancel affordance is conditional behavior, not a static button — flag this for whoever builds the back-gesture handling too, not just the visible Cancel label.

---

### 24. Crew Detail

```
┌─────────────────────────────┐
│ < Back      Crew Name   [⋮] │  <- overflow: Manage Members / Leave
├─────────────────────────────┤
│ (photo) Crew Name           │
│ Members: (a)(a)(a)(a)(a)(a) │  <- full roster, not truncated
├─────────────────────────────┤
│ Upcoming Tables              │
│ ┌─────────────────────────┐ │
│ │ Dinner Sat  [Filling]   │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ Table history                │
│ ┌─────────────────────────┐ │
│ │ Coffee Jun 2  [Rated]   │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ [ Schedule a Table ]        │
│ [   Open Chat       ]        │
└─────────────────────────────┘
```

**Notes:** This screen deliberately shows the *full* member roster (unlike the Crews List's 5-max stack), so the header region needs to accommodate a wrapping/scrollable roster row without pushing the Upcoming/History sections too far below the fold on larger Crews (up to the 20-member soft cap). "Schedule a Table" fans out to two different destinations (recurring setup vs. ad-hoc create) — worth deciding now whether that's a single button with a sub-choice sheet or two visible buttons, since the wireframe currently shows one button standing in for a branching decision.

---

### 25. Crew Chat

```
┌─────────────────────────────┐
│ < (a)(a)(a) Crew Name   Back│  <- mini header -> Crew Detail
├─────────────────────────────┤
│ You're offline — messages   │  <- only when queue non-empty+offline
│ will send when you're back  │
├─────────────────────────────┤
│ (a) Name: message text  ✓   │  <- others left, Sent
│         message text ⏱ (me) │  <- own right-aligned, Pending
│ ┌─────────────────────────┐ │
│ │ [Tag] shared Table card │ │  <- inline Table card attachment
│ └─────────────────────────┘ │
│         message text ! (me) │  <- Failed, "tap to retry"
├─────────────────────────────┤
│ [+] [ type a message____ ] ➤│
└─────────────────────────────┘

— Empty state —
┌─────────────────────────────┐
│ < (a)(a)(a) Crew Name   Back│
├─────────────────────────────┤
│        (illustration)       │
│   "Say hello to your Crew"  │
│  This is your space to plan │
│  the next one, or catch up. │
├─────────────────────────────┤
│ [+] [ type a message____ ] ➤│  <- input itself is the CTA, no button
└─────────────────────────────┘
```

**Notes:** The three per-message delivery states (Pending clock / Sent check / Failed red-exclamation "tap to retry") need to be legible at bubble-corner size and distinguishable from each other at a glance since color alone can't carry the meaning per the a11y note — worth a dedicated small icon set rather than reusing the same glyph tinted differently. Note the empty state intentionally omits a primary button since the always-present text input is the CTA; don't let a generic empty-state template get applied here with a redundant button bolted on.

---

### 26. Recurring Table Schedule Setup

```
┌─────────────────────────────┐
│ < Cancel   Recurring Table  │
├─────────────────────────────┤
│ Activity type                │
│ (Coffee)(Lunch)(Dinner)...  │
├─────────────────────────────┤
│ Recurrence                  │
│ ( ) Weekly ( ) Biweekly ( ) Monthly│
│ Day: [Thu v]  Time: [7:00pm v]│
├─────────────────────────────┤
│ Location                    │
│ [_____________________]     │
│ [ ] Decide per occurrence   │
├─────────────────────────────┤
│ Ends                        │
│ ( ) After [N] occurrences   │
│ ( ) On date [__________]    │
│ ( ) Until I cancel this series│
├─────────────────────────────┤
│ Next 3 occurrences:          │
│  Thu Jul 10, Jul 24, Aug 7   │
├─────────────────────────────┤
│ [    Confirm Schedule    ]  │
└─────────────────────────────┘
```

**Notes:** The end-condition selector must have no default selection at all — "Until I cancel this series" is an explicit, deliberate choice per spec, not a pre-checked radio, so this radio group should render with none selected on load, which is an easy detail for a generic radio-group component to get wrong (most default to selecting the first option). The "next 3 occurrences" preview needs to recompute live off of three separate inputs (recurrence pattern, day/time, end condition) — worth confirming this region's skeleton-pulse re-triggers correctly on every one of those edits, not just the recurrence-pattern field.

*Assumption flagged during wireframing: the recurrence-pattern row (weekly/biweekly/monthly + day + time) is drawn as three inline controls on one line for compactness — a real build will likely need more horizontal space or a stacked layout on narrow devices; this ASCII line-wrap is not a literal one-row layout mandate.*

---

### 27. Report Flow

```
┌─────────────────────────────┐
│ < Cancel      Report        │
├─────────────────────────────┤
│ Reason (choose one)          │
│ ( ) Harassment                │
│ ( ) Inappropriate content     │
│ ( ) Safety concern             │
│ ( ) No-show                    │
│ ( ) Fake profile / spam        │
│ ─────────────────────────    │  <- visual divider
│ ( ) This happened outside     │  <- distinct group, own heading
│     the app                    │     "Off-platform harassment"
│     For harassment/stalking   │
│     that continued off the    │
│     platform — reviewed        │
│     differently and faster.    │
├─────────────────────────────┤
│ Details (required if above)  │
│ [_________________________]  │
│ [_________________________]  │
├─────────────────────────────┤
│ [ Attach evidence/screenshot]│
├─────────────────────────────┤
│ [x] Also block this person   │  <- pre-checked for high-severity
├─────────────────────────────┤
│ [    Submit Report       ]   │
└─────────────────────────────┘
```

**Notes:** This is the screen most worth slowing down on — the off-platform-stalking reason is required by spec to be "visually and semantically separated by a divider, not buried among the generic reasons," with its own screen-reader group heading, and it flips the detail field from optional to required, so its selected-state treatment needs to visibly communicate "this one behaves differently" the instant it's tapped, not just sit as a sixth identical radio row below a thin rule. Someone reporting in a hurry or in distress is exactly the user this divider is protecting, so the visual gap and helper subtext both need real weight, not a token 1px line. The pre-checked block toggle also varies by reason (checked for Harassment/off-platform, unchecked otherwise) — that state-dependent default needs to be obvious to the user, not a silent toggle they might not notice was already on.

---

### 28. Block Confirmation

```
┌─────────────────────────────┐
│                              │
│   "Block this person?"      │
│                              │
│  They will not be told.      │
│  They won't appear in your   │
│  Discover results.            │
│  They can't request to join   │
│  your Tables again.            │
│  Shared Crew membership is    │
│  unaffected unless you leave  │
│  that Crew yourself.           │
│                              │
│  [        Block         ]   │  <- destructive (Brick), full weight
│  [        Cancel        ]   │  <- secondary text button
│                              │
└─────────────────────────────┘
```

**Notes:** This is a small modal, but the a11y requirement that the full explanatory copy be announced *before* focus reaches the "Block" button is a build-order detail, not just a layout one — worth flagging explicitly since a naive implementation might let a screen-reader user tab straight to the destructive button. The shared-Crew-membership sentence is flagged in the spec as an assumption (not confirmed product behavior) — the wireframe includes it because the spec calls for it on-screen, but note this line's wording is provisional pending explicit product sign-off.

---

### 29. Trusted Contact Setup

*Revised 2026-08 (architecture readiness pass): this is a per-Table location share, not a persistent saved contact — see `SCREEN_SPECIFICATIONS.md` Screen 29 for the full rationale (a standing "always share" toggle is itself a privacy risk if forgotten). The screen now has two modes, shown below.*

```
— In-Table mode (opened from Live Table Screen or a pre-Table checklist) —
┌─────────────────────────────┐
│ < Back   Share My Location   │
├─────────────────────────────┤
│ Share with:                  │
│ (•) A Crew member            │
│     [ Select Crew member ▾] │
│ ( ) Someone else             │
│     [ Phone number______  ] │
├─────────────────────────────┤
│ What's shared: live location │
│ only — not messages, not      │
│ history. From now until the   │
│ Table ends, is cancelled, or  │
│ you stop sharing — capped at  │
│ 6 hours. They get a one-time  │
│ link, not app access.          │
├─────────────────────────────┤
│ [     Start Sharing       ]  │
└─────────────────────────────┘

— In-Table mode, share already active —
┌─────────────────────────────┐
│ < Back   Share My Location   │
├─────────────────────────────┤
│  Sharing with Priya           │
│  Started 12 min ago            │
│  Auto-expires when this Table  │
│  ends                           │
│ [      Stop Sharing        ]  │
└─────────────────────────────┘

— Explainer mode (opened from Safety Briefing or Settings > Safety,
  no specific Table in context) —
┌─────────────────────────────┐
│ < Back   Location Sharing     │
├─────────────────────────────┤
│ What's shared: live location  │
│ only — not messages, not      │
│ history. You choose per Table  │
│ whether to share, with whom,   │
│ and for how long.               │
├─────────────────────────────┤
│ Active shares                  │
│  Dinner @ Luna's · Priya       │
│  Started 12 min ago  [Stop]    │
├─────────────────────────────┤
│              [    Got it    ] │
└─────────────────────────────┘

— Explainer mode, empty state —
┌─────────────────────────────┐
│        (illustration)       │
│  "No active location shares" │
│  When you join a Table, you   │
│  can share your live location  │
│  with someone you trust — just │
│  for that gathering.            │
└─────────────────────────────┘
```

**Notes:** This screen no longer has a single "default" layout — which of the three sketches above renders depends entirely on whether it was opened with a Table already in context, and getting that routing wrong (e.g., showing the contact-picker form when there's no Table to scope the share to) would silently reintroduce the persistent-contact model this was deliberately redesigned away from. The explainer mode's empty state has no primary button, unlike almost every other empty state in this document — that's intentional, not an oversight, since starting a share requires picking a specific Table first; don't let a generic empty-state template bolt a "Get Started" button onto this one. The plain-language explainer block is doing real safety-trust work and is specified to read as separate, distinctly-paced paragraphs (per the a11y note) rather than one dense block.

---

### 30. Bill Split Setup

```
┌─────────────────────────────┐
│ < Cancel     Split the Bill │
├─────────────────────────────┤
│ ┌───────────┬───────────┬───┴───────┐
│ │Even Split │Host Covers│Custom Amt │  <- 3 equal-weight options,
│ └───────────┴───────────┴───────────┘     none pre-selected
├─────────────────────────────┤
│ Total bill amount            │
│ [ $__________ ]              │
│ Tip [___] Tax [___]          │
├─────────────────────────────┤
│ Attendees                    │
│  Name A ........... $25.00   │
│  Name B ........... $25.00   │
│  Name C ........... $25.00   │  <- auto/zeroed/editable per mode
├─────────────────────────────┤
│ Sum: $75.00 = Total: $75.00 ✓│  <- reconciliation row
├─────────────────────────────┤
│ [  Send Split Requests   ]  │
└─────────────────────────────┘
```

**Notes:** The three-way mode selector is called out explicitly in the spec as a values-driven requirement — "equally sized, equally weighted, no default pre-selected, none styled as more normal" — which is the opposite of how most segmented-control components behave out of the box (they typically pre-select index 0 and give the selected segment a heavier visual treatment than the others). This needs a genuinely custom three-button row, not a repurposed segmented control, and QA should specifically check that no option looks "more selected" before any tap has occurred. The reconciliation row (sum must equal total) is the only hard gate on submission in Custom Amount mode — make sure it's visually tied to the button's enabled state so users understand why Send is disabled.

*Assumption flagged during wireframing: there's no clean way for ASCII box art to convey "equal visual weight" as a property — a real design pass should verify equal sizing empirically (measured widths/padding), not just eyeball it against this sketch.*

---

### 31. Split Request / Payment Detail

```
┌─────────────────────────────┐
│ < Back      Payment Detail   │
├─────────────────────────────┤
│ Dinner · Sat Jul 4 · Host X  │
│ Amount owed: $25.00          │
│ [ Requested ]                │  <- payment status chip
│                              │  (distinct vocab from RSVP chips)
├─────────────────────────────┤
│ (Payer view)                 │
│ [      Pay Now           ]  │
│ [   Dispute this charge   ]  │  <- secondary, same screen
├─────────────────────────────┤
│ Timeline                     │
│  Requested -> (Paid/Disputed │
│   -> Under Review -> ...)    │
└─────────────────────────────┘

— Key alternate state (Host view) —
┌─────────────────────────────┐
│ < Back      Payment Detail   │
├─────────────────────────────┤
│ Dinner · Sat Jul 4           │
│ Attendee payment status:      │
│  Name A     [ Paid ]         │
│  Name B     [ Requested ]    │
│  Name C     [ Disputed ]     │
│  (no Pay Now action - host)  │
└─────────────────────────────┘
```

**Notes:** One screen adapts to two very different roles (payer gets Pay Now + Dispute; host gets a read-only roster of everyone's status) — the wireframe splits these as two states because conflating them risks a host accidentally seeing a "Pay Now" button meant for someone else's charge. The payment status chip vocabulary (Requested/Paid/Disputed/Refunded) must visually read as a distinct system from the RSVP chip vocabulary (Going/Requested/Waitlisted) even though both use the word "Requested" — reusing identical chip styling for both would make the two axes (attendance vs. payment) look conflated at a glance, which the spec explicitly says they are not.

*Assumption flagged during wireframing: the timeline is shown as a single text line rather than a visual stepper, since a branching path (Requested → Paid vs. Requested → Disputed → Under Review → Refunded/Resolved) doesn't compress well into low-fidelity ASCII — a real design pass should decide whether this is a linear stepper, a log list, or a branching diagram.*

---

### 32. Profile / Me

```
┌─────────────────────────────┐
│ (avatar)  Name  ✓     [⚙]  │  <- settings gear
│ "bio text..."                │
│ (interest)(interest)(interest)│
├─────────────────────────────┤
│ [TableCrew+ upsell banner]  │  <- or "Active" status banner
├─────────────────────────────┤
│ Crews                        │
│ (a)(a)(a) Crew A  ...        │
├─────────────────────────────┤
│ Table history                │
│  Dinner Jun 2   [Rated ★4.8]│
│  Coffee May 20  [Pending]    │  <- simultaneous-reveal, no partial
├─────────────────────────────┤
│ [     Edit Profile       ]  │
└─────────────────────────────┘
```

**Notes:** The "Pending" rating state is a hard rule, not a visual nicety — a rating must never show as one-sided even if the current user already submitted theirs, so the history row's Pending chip needs to look deliberately non-informative (no partial stars, no "waiting on them" hint that could reveal who has/hasn't rated). Table history only lists Rated Tables; Tables in earlier lifecycle states are simply absent from this list rather than shown greyed-out, which is worth confirming with design since it's a different pattern from most of the other list screens in this spec that show status chips for every state.

---

### 33. Settings

```
┌─────────────────────────────┐
│ < Back        Settings      │
├─────────────────────────────┤
│ Account                      │
│  Edit Profile            >  │
│  Data Export/Delete Acct >  │
├─────────────────────────────┤
│ Notifications                │
│  Notification Preferences > │
├─────────────────────────────┤
│ Safety & Privacy             │
│  Show me in Discover   [x]  │  <- inline toggle, not a row->screen
│  Trusted Contact          > │
│  Blocked Users             >│
│  Report Someone           > │
├─────────────────────────────┤
│ Subscription                  │
│  TableCrew+ (Free)        >  │
├─────────────────────────────┤
│ Support                       │
│  Help / Support            > │
├─────────────────────────────┤
│      Log Out                 │  <- destructive-styled row
├─────────────────────────────┤
│  v1.2.3 (build 456)           │
└─────────────────────────────┘
```

**Notes:** This screen mixes two row types — plain navigation rows (chevron) and an inline boolean toggle ("Show me in Discover") — sitting in the same list style, which is a common place for a generic settings-list component to render inconsistently; worth explicitly distinguishing toggle rows from navigation rows in the visual spec so they aren't accidentally both rendered with chevrons or both with switches. Note that turning off Discover visibility is a low-risk, reversible, offline-queueable action while nearly everything else reachable from this screen (Trusted Contact, Report, payment/subscription actions) is offline-blocked — that split in behavior should probably be reflected in some visual or copy distinction so a user doesn't assume all Settings changes save instantly regardless of connectivity.

---

### 34. TableCrew+ Subscription

```
┌─────────────────────────────┐
│ < Back      TableCrew+      │
├─────────────────────────────┤
│ Status: Free                 │  <- or "Active" / "Cancelled, active
│                              │     until Aug 14"
├─────────────────────────────┤
│ Benefits                      │
│  - Priority Discover placement│
│    (surfaced earlier when      │
│     otherwise tied)            │
│  - No per-booking service fee │
│  - Unlimited hosted Tables     │
├─────────────────────────────┤
│ $9.99/mo, billed monthly      │
├─────────────────────────────┤
│ [       Subscribe        ]  │  <- free user
│                              │
│ Restore Purchase              │
└─────────────────────────────┘

— Key alternate state (Active subscriber) —
┌─────────────────────────────┐
│ Status: TableCrew+ Active     │
│ ...benefits list...            │
│ [  Cancel Subscription   ]   │  <- same weight/reachability as
│                              │     Subscribe was, no burial
└─────────────────────────────┘
```

**Notes:** The spec is explicit that "Cancel Subscription" must be just as visually prominent and immediately reachable as "Subscribe" was for a free user — no retention-offer interstitial, no submenu — so the wireframe deliberately puts Cancel in the exact same primary-button slot Subscribe occupied, not demoted to a small text link. Whoever builds this should treat that equal-prominence requirement as a hard constraint tied to the platform's no-dark-patterns value, not just a suggestion, and it's worth a specific design review checkpoint before ship.

---

### 35. Notification Center

```
┌─────────────────────────────┐
│ < Back   Notifications  Mark all read│
├─────────────────────────────┤
│ (All)(Tables)(Crews)(Payments)(Safety)│  <- filter chips
├─────────────────────────────┤
│ ● [Tag] Table update          │  <- unread, bold
│   "Sat's Table is now..."      │
│   2h ago                        │
├─────────────────────────────┤
│   [Tag] Crew message            │  <- read
│   "New message in Crew A"       │
│   1d ago                        │
├─────────────────────────────┤
│ ● [Tag] Payment request         │
│   "Host requested $25..."       │
│   2d ago                        │
├─────────────────────────────┤
│  Notification Preferences   > │
└─────────────────────────────┘

— Empty state —
┌─────────────────────────────┐
│        (illustration)       │
│        "Nothing yet"         │
│  When something needs your   │
│  attention it'll show up here│
└─────────────────────────────┘
```

**Notes:** Unread state must be conveyed through actual accessible text ("unread"), not bold weight alone — worth double-checking the chosen unread indicator (dot + bold, in this sketch) renders as an announced state and not just a visual cue. The Safety filter chip deserves a second look given the linked rule that Safety-category notifications can never be fully muted in preferences — that constraint lives on a different screen (Notification Preferences) but a reviewer should confirm this filter chip doesn't imply Safety notifications are optional/equal-weight to the other four categories.

---

### 36. Data Export / Delete Account

```
┌─────────────────────────────┐
│ < Back   Data & Account      │
├─────────────────────────────┤
│ Your profile, messages,       │
│ RSVPs, and location history   │
│ are deleted or anonymized      │
│ immediately. A minimal record  │
│ of payment transactions is     │
│ kept anonymized for ~7 years,   │
│ as required by law — it can't  │
│ be linked back to your name.   │
├─────────────────────────────┤
│ [    Export My Data      ]  │  <- primary action, default weight
├─────────────────────────────┤
│                              │
│ [    Delete Account      ]  │  <- separate, destructive/Brick,
│                              │     visually secondary to Export
└─────────────────────────────┘

— Key alternate state (Delete flow, step 2 of 2) —
┌─────────────────────────────┐
│ < Back    Confirm Deletion   │
│                              │
│ Re-authenticate               │
│ [ password / biometric___ ]  │
│                              │
│ Type DELETE to confirm         │
│ [_________________________]  │
│                              │
│ Your account will be           │
│ scheduled for deletion; you    │
│ have 14 days to cancel this    │
│ before it's final.              │
│                              │
│ [   Confirm Deletion     ]   │  <- disabled until both fields valid
└─────────────────────────────┘
```

**Notes:** The retention-exception paragraph is specified as always-visible plain text, not a tooltip or collapsed disclosure, so it needs to sit above the fold on the main screen exactly as drafted here, not get compressed into a "Learn more" link to save space — that would violate the honesty-critical disclosure requirement. The re-authentication + typed-"DELETE"-confirmation flow is two distinct gates stacked in sequence (not one screen with one button), so the wireframe separates them as a second screen/step; a reviewer should confirm the submit button truly stays disabled until *both* the re-auth step succeeds and the typed string matches exactly, since collapsing this into a single-screen form risks someone typing DELETE before actually re-authenticating.

---

## Uncertain representations (flagged, not left silently vague)

- **Screen 26 (Recurring Table Schedule Setup):** the recurrence-pattern row (weekly/biweekly/monthly + day + time) is compressed onto one ASCII line for compactness; a real build will likely need more horizontal space or a stacked layout on narrow devices.
- **Screen 30 (Bill Split Setup):** the three-way mode selector is drawn as three boxes sharing top borders to suggest "one connected control, three equal panes" — there's no clean ASCII way to show "equal visual weight" as a property, so a real design pass should verify equal sizing empirically rather than eyeballing it.
- **Screen 31 (Split Request / Payment Detail):** drawn as two separate full wireframes for payer vs. host views since they diverge enough (different primary actions, host sees a roster) that a single merged sketch would be misleading; confirm this is in fact one screen with conditional rendering and not two screens, since `SCREEN_SPECIFICATIONS.md` calls it "the same screen adapting."
- Timeline/status-history elements (Screens 30–31) are shown as a single text line rather than a visual stepper, since a box-drawing stepper with variable branch paths doesn't compress well into low-fidelity ASCII; a real design pass should decide whether this is a linear stepper, a log list, or a branching diagram.
- **Screen 12 (Invite & Share Sheet):** only the Crew-only and Open variants are drawn; the Discover-listed variant is a third distinct configuration (an informational card above the same link tools) that still needs its own review pass rather than being inferred from these two.

## How this document is used

Design and Product should walk through this document screen by screen before any Flutter work begins on a given flow, using each screen's Notes callout as a checklist item to resolve (not just read past). Once a screen's real visual design is underway in Figma per `DESIGN_SYSTEM.md`, that screen's entry here should be marked superseded rather than deleted, so the reasoning behind early layout decisions isn't lost — add a one-line "Superseded by Figma frame X" note rather than removing the wireframe outright.
