# Screen Specifications

**Status:** Living document, v1.0. **Owners:** Product, Design, Engineering jointly. **Related docs:** `PRODUCT.md`, `PRD.md`, `FEATURES.md`, `DATABASE.md`, `API_SPEC.md`, `DESIGN_SYSTEM.md`, `COPY_GUIDELINES.md`, `SECURITY.md`, `SUCCESS_METRICS.md`.

This is the binding contract between Product, Design, and Engineering for every screen in the TableCrew app. It is not a list of screens — it is a full specification for each one: purpose, primary user, entry/exit points, UI components, API calls, validation rules, loading/empty/offline behavior, analytics events, accessibility notes, and future enhancements. Implementation must match this document, and any deviation discovered during build requires updating this document in the same change, per `CLAUDE.md`'s cross-document-consistency rule — a screen spec that silently drifts from the shipped screen is exactly the kind of documentation bug this repository treats as a correctness failure, not cleanup for later.

Every screen below is grounded in already-decided product facts rather than invented independently: RSVP states are exactly **Going / Requested / Waitlisted / Not Going** (`COPY_GUIDELINES.md`); the Table lifecycle is **Proposed → Filling → Confirmed → Happened → Rated**, with **Cancelled** reachable from Proposed, Filling, or Confirmed (`PRD.md`); headcount is a hard **2–8** range with activity-dependent recommended defaults, not one fixed number (`PRODUCT.md`); the minimum platform age is **18**, enforced at signup (`LEGAL.md` §8); and every mutating, capacity- or payment-critical API call carries a client-generated `idempotencyKey` (`API_SPEC.md`, `SERIES_A_DILIGENCE_REVIEW.md` §3). Design-system references (Terracotta primary buttons, RSVP status chips, Table/Crew Card components, skeleton-pulse loading, illustration-plus-Fraunces-plus-Inter empty states, RTL mirroring) are used by name throughout rather than restated — see `DESIGN_SYSTEM.md` for the underlying token definitions.

**A note on completeness, in the spirit of this repository's no-silent-gaps standard:** several screens below surfaced real gaps in `API_SPEC.md` while being specified — a duress-signal endpoint, a payment-dispute endpoint, account export/deletion endpoints, a subscription-checkout endpoint, and a trusted-contact CRUD endpoint. None of these were invented with a fake name to paper over the gap; each is called out explicitly in that screen's Future Enhancements field and rolled up in `TASKS.md` as tracked follow-up work for whoever owns `API_SPEC.md` next.

## Table of Contents

**Onboarding & Authentication**
1. [Splash / Launch Screen](#1-splash--launch-screen)
2. [Phone Number Entry](#2-phone-number-entry)
3. [OTP Verification](#3-otp-verification)
4. [Date of Birth Entry (Age Gate)](#4-date-of-birth-entry-age-gate)
5. [Profile Setup](#5-profile-setup)
6. [Interest Selection](#6-interest-selection)
7. [Notification Permission Priming](#7-notification-permission-priming)
8. [Identity Verification (Tier 2 — ID + Liveness)](#8-identity-verification-tier-2--id--liveness)

**Home & Table Lifecycle**
9. [Home (My Tables)](#9-home-my-tables)
10. [Create Table](#10-create-table)
11. [Venue Picker](#11-venue-picker)
12. [Invite & Share Sheet](#12-invite--share-sheet)
13. [Table Detail](#13-table-detail)
14. [Live Table Screen (day-of, with duress control)](#14-live-table-screen-day-of-with-duress-control)
15. [Table Chat](#15-table-chat)
16. [Waitlist Screen](#16-waitlist-screen)
17. [Post-Table Rating](#17-post-table-rating)

**Discover**
18. [Discover Feed](#18-discover-feed)
19. [Discover Filters](#19-discover-filters)
20. [Discover Table Preview](#20-discover-table-preview)
21. [First-Time Safety Briefing](#21-first-time-safety-briefing)

**Crews**
22. [Crews List](#22-crews-list)
23. [Create Crew](#23-create-crew)
24. [Crew Detail](#24-crew-detail)
25. [Crew Chat](#25-crew-chat)
26. [Recurring Table Schedule Setup](#26-recurring-table-schedule-setup)

**Trust & Safety**
27. [Report Flow](#27-report-flow)
28. [Block Confirmation](#28-block-confirmation)
29. [Trusted Contact Setup](#29-trusted-contact-setup)

**Payments**
30. [Bill Split Setup](#30-bill-split-setup)
31. [Split Request / Payment Detail](#31-split-request--payment-detail)

**Account & Settings**
32. [Profile / Me](#32-profile--me)
33. [Settings](#33-settings)
34. [TableCrew+ Subscription](#34-tablecrew-subscription)
35. [Notification Center](#35-notification-center)
36. [Data Export / Delete Account](#36-data-export--delete-account)

---

## Part 1: Onboarding, Home & Table Lifecycle

---

### 1. Splash / Launch Screen

#### Purpose
Branded launch surface shown while the app performs cold-start work: initialize Firebase, check auth token validity/refresh, resolve a deep link if the app was opened via a share/invite link, and determine the correct routing destination (unauthenticated → Phone Number Entry; authenticated but mid-onboarding → resume at the correct step; authenticated and complete → Home). Should route in well under 2 seconds on a warm start.

#### Primary User
All users, on essentially every cold app launch.

#### Entry Points
- OS launch via app icon tap
- Deep link / universal link tap (e.g., a Table invite link, a Crew invite link) when the app is not already running
- Push notification tap when the app was fully terminated

#### Exit Points
- Phone Number Entry (new or logged-out user)
- Resumed onboarding step — Profile Setup, Interest Selection, etc. — if a prior session ended mid-onboarding
- Home (My Tables) — fully onboarded, authenticated user, no deep link present
- Table Detail or the Invite & Share Sheet acceptance flow — authenticated user who launched via a Table/Crew invite deep link
- Identity Verification — authenticated user with a pending Tier 2 verification triggered by a previous Discover/Open Table attempt

#### UI Components
- Full-bleed Card Cream background
- Centered TableCrew wordmark (Fraunces), no body copy, no buttons
- A single thin skeleton-pulse bar beneath the logo, shown only if cold-start work exceeds 800ms (see Loading States) — the screen is otherwise static

#### API Calls
No user-facing business endpoint is called from this screen. It triggers a Firebase Auth token refresh/validation. Profile-completeness routing is read from locally cached auth/session claims rather than a network round trip, so Splash stays fast and works at least partially offline.

#### Validation Rules
N/A — no user input. Deep link tokens are validated for well-formedness before being handed to the router; malformed or expired invite tokens fall through to Home with a non-blocking toast rather than an error screen.

#### Loading States
If auth/session resolution finishes in under 800ms, no loading indicator appears at all. Past 800ms, a single skeleton-pulse bar (Card Cream tone) appears beneath the wordmark — never a spinner. A hard 5-second timeout routes to Phone Number Entry while a cached-session check keeps retrying in the background.

#### Empty States
Not applicable — no collection/list content. If deep-link resolution fails outright (no connectivity, no cached destination), the screen falls through to default authenticated/unauthenticated routing instead of showing an error.

#### Offline Behavior
Fully offline-capable for returning users: a valid cached auth session routes straight to Home using cached data (see Home's offline behavior) without waiting on the network. New/logged-out users with no connectivity route to Phone Number Entry, which itself surfaces the offline state on submission attempt.

#### Analytics Events
- `app_launched` (new — snake_case; properties: cold vs. warm start, launch source [icon/deep-link/push], time-to-route in ms)

#### Accessibility Notes
Wordmark is exposed to screen readers as a single "TableCrew, loading" label rather than a decorative image. The screen auto-advances, so no interactive element needs a focus target. Respects the OS reduced-motion setting by using a static logo fade instead of an animated shimmer loop.

#### Future Enhancements
A seasonal/time-of-day variant of the launch background is worth considering later but is not built for v1, to keep launch performance and asset weight minimal. Assumption: no server-driven "what's new" card is shown here in v1 — that content lives in Home, keeping Splash's only job fast routing.

---

### 2. Phone Number Entry

#### Purpose
Collect and validate a phone number as the primary account identifier and kick off Tier 1 (phone) verification via SMS OTP.

#### Primary User
New signups and returning users who've signed out or switched devices.

#### Entry Points
- Splash routing for unauthenticated users
- "Log out" from Settings
- "Switch account" flow
- Resuming an abandoned signup

#### Exit Points
- OTP Verification (successful submission)
- Back to Splash / exit app (back gesture on first launch)
- A "Have an issue?" link out to a support contact sheet

#### UI Components
- Fraunces headline: "What's your number?"
- One sentence of Inter body copy explaining SMS use
- Country-code selector (defaults to device locale, searchable native list)
- Single phone number field with live formatting
- Terracotta primary button ("Send Code"), disabled until the number is plausible for the selected country
- Small-print legal copy linking Terms/Privacy

#### API Calls
Client-side call into Firebase Auth's phone-auth flow to trigger the SMS OTP send. This is infra-level auth, not one of the named TableCrew business endpoints, so no `idempotencyKey` applies here.

#### Validation Rules
- Number must parse as valid for the selected country (libphonenumber-style validation) before "Send Code" enables
- Known VOIP/disposable-number prefixes trigger a soft warning, not a hard block, since false positives are common
- Rate limit: after 5 send attempts to the same number within 15 minutes, the button disables and a cooldown timer is shown instead of a silent failure

#### Loading States
On tapping "Send Code," the button itself morphs into an inline skeleton-pulse (Card Cream) in place of its label — no full-screen spinner, no separate loading screen, so the user's input context is never lost.

#### Empty States
N/A — single-field form, no list/collection content.

#### Offline Behavior
If the device is offline when "Send Code" is tapped, the button shows an inline error state ("You're offline — we'll retry automatically") and the request auto-retries on reconnect for up to 60 seconds before failing explicitly and asking for a manual retry. The entered phone number and country code persist locally so nothing is lost.

#### Analytics Events
- `onboarding_step_completed` (new — snake_case; `step: "phone_entry"`), fired on successful OTP send

#### Accessibility Notes
The country-code picker is a native accessible picker (not a custom dropdown) so VoiceOver/TalkBack search works correctly. The phone field uses the platform's telephone-number input type to surface the correct numeric keyboard. Error/cooldown states are announced via a live region, not conveyed by color alone.

#### Future Enhancements
WhatsApp OTP as a fallback delivery channel for regions with unreliable SMS delivery is worth adding, but requires a separate Meta Business API integration — flagged as an open decision pending international expansion, not built in v1.

---

### 3. OTP Verification

#### Purpose
Confirm the user controls the phone number they entered by validating a one-time SMS code, completing Tier 1 verification.

#### Primary User
New signups and returning users mid-authentication.

#### Entry Points
Successful submission from Phone Number Entry.

#### Exit Points
- Date of Birth Entry (Age Gate) — brand-new accounts
- Home (My Tables) — returning users whose profile is already complete
- Back to Phone Number Entry (to correct the number)

#### UI Components
- Fraunces headline confirming the masked number ("Enter the code we sent to •• ••34")
- 6-digit segmented code input with auto-advance per digit
- Terracotta primary button ("Verify") that auto-submits once all 6 digits are entered
- "Resend code" text link, tappable after a 30-second countdown
- "Edit number" link back to Phone Number Entry

#### API Calls
Firebase Auth phone-credential confirmation (infra-level, not a named business endpoint). No account-creation business call fires yet on first-ever verification — that's deferred to Profile Setup completion.

#### Validation Rules
- Code must be exactly 6 numeric digits
- An incorrect code triggers an inline shake + error message without clearing the field, so a single mistyped digit is easy to spot
- After 5 incorrect attempts, the field locks for 60 seconds
- Codes expire after 5 minutes, automatically surfacing the "Resend code" call to action

#### Loading States
The "Verify" button transitions into an inline skeleton-pulse the instant the 6th digit is entered (auto-submit) — the user never manually confirms submission.

#### Empty States
N/A.

#### Offline Behavior
If offline at auto-submit time, the code is held locally and verification is retried automatically on reconnect for up to 60 seconds, shown as an inline "Reconnecting..." skeleton-pulse (never a spinner); beyond that window, an explicit retry button appears.

#### Analytics Events
- `onboarding_step_completed` (new; `step: "otp_verified"`)

#### Accessibility Notes
The segmented code input is exposed to assistive tech as a single accessible text field with a 6-digit numeric hint, not six separately unlabeled boxes, so screen reader users aren't forced to navigate cell-by-cell. SMS one-time-code autofill (iOS/Android) is supported so most users never type manually.

#### Future Enhancements
A biometric (Face ID/Touch ID) short-circuit for returning users on a recognized device, skipping OTP on subsequent logins, is worth exploring but not built in v1 — flagged as open pending a security review of device-trust duration.

---

### 4. Date of Birth Entry (Age Gate)

#### Purpose
Collect self-reported date of birth and enforce TableCrew's 18+ minimum age at signup, before any profile or social data is created.

#### Primary User
New signups only — shown exactly once, immediately after first-ever OTP verification.

#### Entry Points
OTP Verification, first-time account creation path only.

#### Exit Points
- Profile Setup (DOB accepted, computed age ≥ 18)
- A hard-stop "You must be 18+" screen with no bypass (computed age < 18), offering only account deletion / sign-out

#### UI Components
- Fraunces headline: "When's your birthday?"
- One sentence of Inter body explaining this determines eligibility and is never shown on the public profile
- Native date-of-birth picker (day/month/year wheels or platform date input)
- Terracotta primary button ("Continue"), disabled until a complete, plausible date is selected

#### API Calls
No dedicated named endpoint fires from this screen alone. DOB is staged locally and written as part of the account/profile document created at Profile Setup completion; the age check itself is a lightweight server-side validation round trip (see Loading/Offline below), not one of the seven named business endpoints.

#### Validation Rules
- Date must be a real calendar date (no Feb 30) and not in the future
- Computed age must be ≥ 18 as of today, **server-validated against a minimum date** at account-creation time — not solely a client-side gate, since client clocks/logic can be manipulated
- If computed age is under 18, no account is created and the user sees the hard-stop screen
- **Tier 2 cross-check:** because this is a self-reported field with no appeal path at signup, Identity Verification (Tier 2, via Persona) later cross-checks this DOB against the user's government ID for anyone who attempts to reach Discover or an Open Table. A mismatch revealing under-18, or a discrepancy beyond a reasonable data-entry margin, triggers automatic account suspension and a Trust & Safety review rather than silently trusting the original self-report indefinitely.

#### Loading States
"Continue" shows an inline skeleton-pulse while the server-side age check completes — a network round trip specifically because this is a trust-and-safety-relevant validation, not a purely client-side gate.

#### Empty States
N/A.

#### Offline Behavior
DOB entry is cached locally as a draft. Because the age check requires a server round trip by design (to prevent tampering), "Continue" stays disabled while offline, with an inline message ("We need a connection to verify your age") rather than allowing optimistic local progression.

#### Analytics Events
- `onboarding_step_completed` (new; `step: "dob_entered"`)
- An internal (non-client) metric tracks age-gate rejection rate; it is not part of the client analytics event list.

#### Accessibility Notes
A native date picker is used (not a custom scroll wheel) to guarantee correct screen-reader semantics for day/month/year values. The hard-stop under-18 screen uses plain, non-alarming Fraunces/Inter copy per `docs/COPY_GUIDELINES.md` tone rather than red error styling, since this is a policy boundary, not a user error.

#### Future Enhancements
None deferred on the core gate — age-gating is safety-critical and fully specified for v1. Open item: the exact wording and data-retention handling of the account-deletion path off the hard-stop screen should get explicit legal/Trust & Safety sign-off before ship, since it touches a never-completed account.

---

### 5. Profile Setup

#### Purpose
Collect the minimum profile data needed to create the account record and represent the user on Table Cards and Crew Cards: name, photo, and short bio.

#### Primary User
New signups, immediately after passing the age gate.

#### Entry Points
Date of Birth Entry (age accepted).

#### Exit Points
Interest Selection (on save). There is no back-exit to DOB from here — changing DOB later requires a Settings support flow, since it's an age-gate field.

#### UI Components
- Fraunces headline: "Let's set up your profile"
- Profile photo picker (camera or library, **required** — Table Cards always show a real photo, never a default avatar)
- First name field (required)
- Last-initial-only field (optional; matches how names render on Table Cards for non-Crew members)
- 140-character bio text area (optional)
- Terracotta primary button ("Continue")

#### API Calls
Photo upload to Cloud Storage; account/profile document creation (the record `createTable`, `requestSeat`, etc. later reference as the acting user), bundled at this step rather than exposed as a separate named endpoint.

#### Validation Rules
- First name required, 1–30 characters, soft profanity/impersonation filter (warning, not hard block, to avoid false positives on legitimate names)
- Photo required before "Continue" enables — client-side minimum-resolution check (400x400) plus a friendly (non-blocking) nudge if the image looks obviously non-human (e.g., a pure logo or screenshot)
- Bio capped at 140 characters with a live counter

#### Loading States
The photo picker shows a skeleton-pulse placeholder in the exact aspect ratio of the final avatar (Card Cream tone) while uploading, so layout never jumps. "Continue" disables and shows an inline skeleton-pulse during document save.

#### Empty States
The photo picker's unselected state is a dashed-outline tile with a camera icon and Inter microcopy ("Add a photo") rather than a blank tile.

#### Offline Behavior
Name and bio persist as a local draft immediately (no data loss on backgrounding). Photo upload queues and retries automatically on reconnect, with a persistent inline "Uploading when you're back online" banner. "Continue" stays disabled until the photo upload confirms server-side — a Table Card can never render with a missing avatar.

#### Analytics Events
- `onboarding_step_completed` (new; `step: "profile_setup"`)

#### Accessibility Notes
The photo picker exposes an accessible label describing whether a photo is currently selected. The bio counter is announced via live region as the limit approaches (last 10 characters), not conveyed by color change alone. The last-initial field is clearly labeled optional so screen reader users don't perceive it as a blocked required field.

#### Future Enhancements
Prompt-based profile fields (e.g., "best conversation you've had at a Table") to enrich Discover matching are being considered but deferred — Profile Setup stays minimal in v1 to reduce signup friction; richer optional fields can be added later from Settings without touching this screen's core flow.

---

### 6. Interest Selection

#### Purpose
Collect the activity/interest tags (Coffee, Lunch, Dinner, Founder Dinners, Board Games, Hiking, Mentorship, etc.) that drive both Discover matching and the default headcount recommendation later shown on Create Table.

#### Primary User
New signups, immediately after Profile Setup; also reachable later from Settings to edit.

#### Entry Points
Profile Setup (save); Settings → "Edit interests."

#### Exit Points
Notification Permission Priming (first-time onboarding path); Settings (if entered via the Settings edit flow).

#### UI Components
- Fraunces headline: "What kind of Tables are you into?"
- One sentence of Inter body: "Pick at least 3 — you can change these anytime"
- Wrapping grid of tappable interest chips, each with a filled/Terracotta-Light selected state
- Live counter ("3 selected")
- Terracotta primary button ("Continue"), disabled until the minimum is met

#### API Calls
Interests are written to the user's profile document as part of the same account-creation write as Profile Setup on first-time onboarding (no separate named endpoint); on the Settings edit path this is a plain profile field update.

#### Validation Rules
- Minimum 3 interests required to enable "Continue," ensuring Discover/matching has enough signal
- No hard maximum; the grid soft-caps visually before scrolling
- Duplicate selection is impossible by construction (toggle-only, not free text)

#### Loading States
The chip grid loads instantly from a bundled static taxonomy — no network fetch needed to render options, so there's no loading state for the grid itself. "Continue" shows an inline skeleton-pulse while the selection saves.

#### Empty States
N/A in the traditional sense — chips are always present. The "0 selected" state keeps "Continue" disabled with subtle Inter helper text ("Pick at least 3 to continue").

#### Offline Behavior
Selections persist locally the instant each chip is tapped (no network dependency to select). On "Continue," if offline, selections queue and sync on reconnect, and onboarding proceeds optimistically to Notification Permission Priming — interest data isn't safety- or identity-critical the way DOB is — with a background sync banner confirming once saved.

#### Analytics Events
- `onboarding_step_completed` (new; `step: "interest_selection"`, properties: `interest_count`, selected tag list)

#### Accessibility Notes
Chips are accessible toggle buttons with selected/not-selected state announced (not color-only — selected chips also carry a checkmark glyph). The grid supports full keyboard/switch-control navigation in logical reading order. RTL layout mirrors chip flow direction per the design system's RTL standard.

#### Future Enhancements
Personalized interest-order suggestions based on Discover activity in the user's metro area (e.g., surfacing "Board Games" first where it's popular) are deferred — v1 shows the full taxonomy in a fixed, editorially-curated order for consistency.

---

### 7. Notification Permission Priming

#### Purpose
Explain, in plain language and before the OS system prompt appears, why TableCrew wants push permission (Table invites, RSVP changes, chat messages, day-of reminders), so opt-in reflects informed consent rather than a bare OS dialog with no context.

#### Primary User
New signups, end of onboarding.

#### Entry Points
Interest Selection (save), onboarding path only.

#### Exit Points
Home (My Tables), fully onboarded at Tier 1. (Tier 2 identity verification is deliberately *not* forced here — it's deferred until the user actually attempts to host/join an Open or Discover Table; see Identity Verification.)

#### UI Components
- Fraunces headline: "Don't miss your Table"
- Illustration of a phone with a friendly notification bubble (not an alarming red badge)
- One sentence of Inter body explaining the three notification categories: invites, RSVP/chat updates, day-of reminders
- Terracotta primary button ("Turn on notifications") that triggers the native OS permission dialog
- Secondary text-only "Not now" link (never a second full-weight button, keeping one primary action per screen)

#### API Calls
None — this screen only triggers the native OS permission API; no business endpoint call.

#### Validation Rules
N/A — permission grant/deny is an OS-level binary outcome, not a validated form field.

#### Loading States
N/A — the OS system dialog itself is the interstitial; TableCrew renders no custom loading state around it.

#### Empty States
N/A.

#### Offline Behavior
Fully functional offline — requesting OS notification permission has no network dependency. The user's choice is cached locally and reconciled with backend push-token registration the next time the app has connectivity.

#### Analytics Events
- `onboarding_step_completed` (new; `step: "notification_priming"`, property `permission_granted: true/false`)

#### Accessibility Notes
The illustration is marked decorative (no meaningful alt text needed beyond the surrounding copy). Both the primary and "Not now" controls are large touch targets, reachable via a single swipe in screen-reader linear navigation order.

#### Future Enhancements
A granular per-category notification toggle (e.g., chat pushes on, day-of reminders off) already belongs conceptually in Settings and is out of scope here — this screen intentionally asks for one blanket OS permission to avoid onboarding decision fatigue; granular control is a post-onboarding Settings concern.

---

### 8. Identity Verification (Tier 2 — ID + Liveness)

#### Purpose
Verify a user's real identity via government ID capture plus a selfie liveness check, run through the Persona SDK, as the gate required before a user may host or join any Open or Discover Table (Tier 2). Framed explicitly as identity verification, never as a criminal background check — that distinction is legally real and must not be blurred in copy.

#### Primary User
Any Tier-1-only user attempting their first Open/Discover Table action — hosting via Create Table with Open/Discover visibility, or requesting a seat via `requestSeat` on an Open/Discover Table. Crew-only/Closed-Table use never requires this screen.

#### Entry Points
- Create Table, at the point a user selects "Open" or "Discover" visibility for a new Table
- Table Detail / seat-request flow, when a Tier-1-only user taps "Request Seat" on an Open/Discover Table
- Discover surface generally, on first entry

#### Exit Points
- Automatic return to the originating flow (Create Table, Table Detail seat request, or Discover) once verification succeeds
- "Not now" returns to Home, leaving the originating Open/Discover action incomplete (the Table is held as a local draft, or the seat request is not submitted — see Create Table's offline-draft mechanism, which also covers this "come back later" case)
- **A named failure path, not just a named success path:** when Persona returns a `fail` outcome that is *not* the DOB-mismatch/under-18 case (e.g., unreconcilable capture quality after repeated attempts, a liveness-check mismatch, or a suspected-fraud flag), the status card replaces "Verifying..." with a plain, non-alarming "We couldn't verify you this time" message and a Terracotta "Try again" button that re-launches the Persona SDK flow, capped at 3 attempts in a rolling 24-hour window (a reasoned default, flagged in Future Enhancements). Exhausting the retry cap does not lock the account or silently strand the user: it routes to a "Talk to us" support-contact link (the same support surface referenced from Phone Number Entry) so a human can review manually, and the user returns to Home with the originating Open/Discover action left incomplete, exactly as the "Not now" path handles it. This is distinct from the DOB-mismatch case (Validation Rules below), which is never offered a same-screen retry, since that outcome triggers an account-level Trust & Safety review rather than a capture-quality retry.

#### UI Components
- Fraunces headline: "Let's verify it's really you"
- One sentence of Inter body stating plainly: "This confirms your identity so Discover stays real — it is not a background check," plus a secondary line noting the ID/selfie are processed by Persona, TableCrew's verification partner, and are never visible on the public profile
- Terracotta primary button ("Start verification") launching the embedded Persona SDK flow (ID capture → selfie liveness → Persona-side processing)
- Persistent "Why do we ask?" expandable disclosure
- Post-submission status card: "Verifying... usually takes under a minute"

#### API Calls
The Persona SDK handles ID/selfie capture and liveness scoring directly. On Persona's completion callback, the client calls the TableCrew backend to record the verification outcome, which fires `verification_completed`. No TableCrew-built OCR/liveness code exists per `docs/ARCHITECTURE.md`.

#### Validation Rules
Persona's own capture-quality checks (glare, crop, blur) surface inline before submission. TableCrew adds one product-level rule on top of Persona's pass/fail: the DOB on the verified government ID is cross-checked against the self-reported DOB from Date of Birth Entry. A match within reasonable data-entry tolerance (e.g., a single-digit typo) passes silently; a mismatch revealing the user is actually under 18, or a discrepancy beyond that tolerance, fails verification and flags the account for a Trust & Safety review rather than a generic "try again."

#### Loading States
After the Persona SDK hands back capture data, a full-card skeleton-pulse (Card Cream) status card shows "Verifying..." Persona's typical turnaround is under a minute, but the flow supports backgrounding — verification continues server-side and the result arrives as a push notification/in-app banner if the app isn't foregrounded when it completes.

#### Empty States
N/A — linear capture flow, no list/collection content. If the user backs out mid-Persona-flow, "Start verification" simply resets to its initial state rather than showing a broken partial-progress view.

#### Offline Behavior
The Persona SDK's capture steps (camera-based ID scan, selfie) function offline, but submission requires connectivity. If the device goes offline right after capture, the flow holds captured media locally and shows "Waiting for connection to submit" rather than discarding it, retrying automatically once online. Verification cannot be queued as a deferred background task the way non-safety-critical writes can — Persona must process it server-side before the result can gate an Open/Discover action.

#### Analytics Events
- `verification_completed` (existing; properties: outcome [pass/fail/manual-review], triggering surface [create_table / seat_request / discover_browse])

#### Accessibility Notes
Persona's embedded SDK view is a third-party surface with its own accessibility implementation that TableCrew does not control directly. The surrounding TableCrew-built screens (intro, status) are fully screen-reader-labeled, and the "Why do we ask?" disclosure is an accessible expandable region. Camera-based ID capture unavoidably requires some sighted assistance for alignment — a known limitation of ID-capture SDKs generally, disclosed in `docs/SECURITY.md` rather than silently ignored.

#### Future Enhancements
Persona's accessibility-assisted capture (audio-guided ID alignment) isn't currently available as of this writing — flagged as an open external dependency, not a TableCrew build item, to revisit if/when Persona ships one. Assumption made here: re-verification (ID expiry, Persona flagging a stale check) is out of scope for this v1 spec and would reuse this same screen with different entry-point copy — flagged for Product/Trust & Safety to confirm cadence. The 3-attempts-per-24-hours retry cap on a non-DOB-mismatch failure (see Exit Points) is a reasoned default, not a policy specified elsewhere, and should get explicit Trust & Safety sign-off — too generous a cap invites scripted retry abuse against Persona's capture pipeline, too strict a cap strands a legitimate user with a bad camera or poor lighting.

---

### 9. Home (My Tables)

#### Purpose
The default landing surface after onboarding — shows the user's own Tables across lifecycle states (Proposed/Filling/Confirmed/Happened needing rating) plus their Crews, and is the jumping-off point for creating or discovering new Tables.

#### Primary User
Every authenticated, onboarded user, on essentially every app open.

#### Entry Points
- Splash routing (authenticated, onboarded, no deep link)
- Notification Permission Priming (end of onboarding)
- Tab-bar "Home" tap from anywhere else in the app
- Push notification tap that doesn't target a specific Table (e.g., a Crew digest)

#### Exit Points
- Create Table (primary action)
- Table Detail (tapping any Table Card)
- Crew detail (tapping any Crew Card)
- Discover tab (separate primary navigation destination)
- Waitlist Screen (tapping a Table Card the user is Waitlisted on shows position inline, linking through)

#### UI Components
- Top segmented control separating "My Tables" from "My Crews"
- Vertically scrolling list of Table Cards — venue/activity, date/time, RSVP status chip (Sage/Terracotta Light/Gold Ochre/Warm Grey, plus Brick for a Cancelled Table the user was on), stacked-avatar attendee preview
- Crew Cards listing persistent friend groups with a "Schedule a Table" quick action per Crew
- Floating Terracotta primary action button ("Create a Table") pinned to the bottom, the one primary action on this screen

#### API Calls
`searchTables` (scoped to the current user's own Tables, not general Discover search) populates "My Tables"; a Crew-membership read (backed by the same documents `createCrew`/`addMember`/`removeMember` write to) populates "My Crews."

#### Validation Rules
N/A — read/display screen, no form input. Client-side sort order: soonest-upcoming Table first, then Happened-but-unrated Tables surfaced with a rating nudge, then further-future Tables, then Cancelled Tables deprioritized to the bottom.

#### Loading States
First load / pull-to-refresh renders 3–4 skeleton-pulse Table/Crew Card placeholders (Card Cream tone) matching the exact card layout (avatar circle, two text lines, chip pill), so the transition to real content causes no layout shift. Never a spinner.

#### Empty States
A brand-new user with zero Tables sees an illustration of an empty table setting, a Fraunces headline ("Your first Table starts here"), one sentence of Inter body ("Create a Table or find one on Discover"), and the single Terracotta "Create a Table" primary button (the same button as the persistent FAB, not a duplicate). "My Crews" has its own parallel empty state ("No Crews yet — Tables you attend together can become a Crew"), since Crews form from shared Table history rather than being cold-added from Home.

#### Offline Behavior
Home reads from local cache first (last successfully synced Table/Crew list) and renders immediately with a small non-blocking "Offline — showing saved Tables" banner rather than blocking on network. Pull-to-refresh while offline shows an inline "Can't refresh while offline" toast rather than an infinite skeleton-pulse. The "Create a Table" FAB stays tappable offline, routing into Create Table's own offline draft behavior rather than being disabled.

#### Analytics Events
`table_attended` and `table_happened` are fired by the backend/Live Table transition rather than from Home directly, but Home is the surface that displays the "Rate this Table" nudge for any Happened-but-unrated Table, deep-linking on tap to Post-Table Rating.

#### Accessibility Notes
Table Cards and Crew Cards expose one combined accessibility label per card (venue, date, RSVP status, attendee count) rather than forcing screen-reader users to piece together each visual element separately. The segmented "My Tables"/"My Crews" control is a proper accessible tab control with state announced on switch. RTL layout mirrors Table Card avatar-stack and RSVP-chip placement per the design system's RTL standard.

#### Future Enhancements
A unified activity feed merging Table and Crew updates into one chronological stream (instead of two lists) is being considered for later once Crew volume grows — deferred in v1 because most users' Crew counts are low enough that a simple segmented split is clearer.

---

### 10. Create Table

#### Purpose
Let a user propose a new Table — activity/interest tag, venue, date/time, headcount, and visibility (Crew-only/Closed vs. Open vs. Discover) — moving it into the Proposed lifecycle state.

#### Primary User
Any authenticated user. Tier 1 is sufficient for Crew-only/Closed Tables; Tier 2 is required before an Open/Discover Table can actually be published, enforced via the Identity Verification gate.

#### Entry Points
- Home's persistent "Create a Table" FAB and empty-state button
- A Crew Card's "Schedule a Table" quick action (pre-fills the Crew as invitees, defaults straight to Crew-only visibility)
- Table Detail's "Create a similar Table" action on a past Happened Table

#### Exit Points
- Venue Picker (mid-flow, for venue selection)
- Invite & Share Sheet (immediately after successful creation)
- Table Detail (the newly created Table, after Invite & Share is dismissed)
- Identity Verification (interstitial, only if the user selects Open/Discover visibility while still Tier 1)

#### UI Components
- Fraunces headline: "Plan a Table"
- Interest/activity tag selector (single-select, same taxonomy as Interest Selection — drives the headcount default below)
- Venue field launching Venue Picker
- Date/time pickers
- Headcount stepper whose **default value is set by the selected activity tag** — Coffee/Mentorship default range 2–4 (starts at 3), Lunch default range 3–5 (starts at 4), Dinner/Founder-dinners default range 4–6 (starts at 5), Board Games/Hiking default range 4–8 (starts at 6) — with absolute bounds hard-clamped to 2 and 8 regardless of activity
- Visibility toggle (Crew-only/Closed, Open, Discover-listed) with inline explanatory copy per option
- Optional recurring-Table toggle ("Repeat this Table weekly/monthly")
- Terracotta primary button ("Create Table")

#### API Calls
`createTable` (idempotent, requires a client-generated `idempotencyKey`) on submission; `scheduleRecurringTable` instead of/alongside `createTable` when the recurring toggle is enabled; `updateTable` if the user re-enters this screen to edit a still-Proposed Table.

#### Validation Rules
- Activity tag required; venue required (must be selected via Venue Picker — free-text venue name alone is not accepted)
- Date/time must be in the future, with a minimum lead time (e.g., at least 60 minutes out) so invitees have a realistic chance to RSVP
- Headcount stepper hard-clamped 2–8 regardless of activity; the activity-specific recommended sub-range is shown as a visual highlight on the stepper track, not a hard boundary — a host can still pick 7 for a Coffee Table if they want
- Open/Discover visibility cannot be submitted by a Tier-1-only user — attempting it routes to Identity Verification as an interstitial before `createTable` fires, with the draft held locally until verification resolves

#### Loading States
"Create Table" shows an inline skeleton-pulse on tap while `createTable` round-trips. The venue field shows a brief skeleton-pulse card while venue metadata (address, photo) hydrates back into this screen after selection in Venue Picker.

#### Empty States
The venue field's unselected state is a dashed-outline row with a pin icon and Inter microcopy ("Choose a venue") rather than a blank input.

#### Offline Behavior
The entire form persists as a continuous local draft — every field change saves to local storage immediately, not just on exit — so backgrounding or losing connectivity never loses in-progress input. If "Create Table" is tapped while offline, the Table is created locally in a client-only "Draft — will send when back online" state (visually distinct from a real Proposed chip), and `createTable` fires automatically on reconnect using the same `idempotencyKey` generated at draft time, guaranteeing no duplicate Table even if the retry fires more than once.

#### Analytics Events
- `table_created` (existing; properties: activity tag, headcount selected vs. recommended default, visibility, recurring flag)
- `crew_table_scheduled` (existing; fired instead of/alongside `table_created` when entered via a Crew Card's "Schedule a Table" shortcut)

#### Accessibility Notes
The headcount stepper announces both the current value and the activity-specific recommended range on focus ("5 people, recommended 4 to 6 for Dinner"), not relying on a visual highlighted band alone. Visibility toggle options each carry a full accessible description of what Crew-only/Open/Discover mean, since this choice has real safety and verification implications. Date/time pickers use native platform controls for correct assistive-tech behavior.

#### Future Enhancements
Smart venue suggestions based on the selected activity tag and past host behavior (e.g., surfacing previously-used coffee shops first) are a natural extension of Venue Picker's data, deferred to keep Create Table's v1 scope focused on correctness of the core fields — flagged as a Venue Picker enhancement rather than a Create Table one.

---

### 11. Venue Picker

#### Purpose
A focused search-and-select surface for choosing a real, mappable venue for a Table, invoked from Create Table so venues are always structured data (name, address, coordinates) rather than free text.

#### Primary User
Any user mid-Create Table (or editing an existing Proposed Table's venue via `updateTable`).

#### Entry Points
Create Table's venue field tap.

#### Exit Points
Back to Create Table with the selected venue populated; back to Create Table with no change (cancel/back gesture).

#### UI Components
- Search text field at top with live-as-you-type results
- Scrollable results list of venue rows (name, neighborhood/address snippet, category icon)
- Inline embedded map preview showing pins for currently visible results
- "Use current location" affordance to bias search results
- "Can't find it? Add manually" fallback row at the bottom of results, opening a minimal manual-entry form (name + address) for venues not in the provider database — still produces structured data, just human-entered

#### API Calls
A venue/places search call to the underlying maps/places provider per `docs/ARCHITECTURE.md` — third-party places data, not one of the seven core TableCrew business endpoints. No write happens on this screen; the selection is handed back to Create Table's in-memory form state, persisted via that screen's own `createTable`/`updateTable` call.

#### Validation Rules
- Search requires at least 2 characters before firing a query (debounced ~300ms)
- Manual-entry fallback requires both a name and an address line before its own "Use this venue" button enables
- Manually-entered venues are flagged internally as unverified-location so downstream map-pin rendering in Table Detail can degrade gracefully if geocoding fails

#### Loading States
The results list shows 3 skeleton-pulse row placeholders (Card Cream) while a search is in flight; the map preview shows a static neutral-tone placeholder map (no pins) rather than a spinner while pins are computed from results.

#### Empty States
A no-results state shows a small illustration, a Fraunces headline ("No spots found"), one sentence of Inter body ("Try a different search, or add the venue yourself"), and surfaces the "Add manually" fallback directly inline as the primary action — the one Empty State in this document where the "primary button" is the manual-entry fallback rather than a generic retry.

#### Offline Behavior
Venue search requires connectivity (live third-party API call). If offline, the search field shows "You're offline — search isn't available right now," and the screen leads directly with the manual-entry fallback so venue selection is never fully blocked by connectivity. A manually-entered offline venue syncs/geocodes in the background once connectivity returns, consistent with Create Table's own local-draft pattern.

#### Analytics Events
No dedicated existing event for venue search; venue source (provider-matched vs. manual) is tracked as a property on `table_created` rather than as its own funnel event, to avoid over-instrumenting a picker screen.

#### Accessibility Notes
Results list rows are fully accessible list items (name, address, category read as one combined label). The map preview is marked decorative/supplementary since the results list already conveys the same information textually — screen reader users are never required to interact with the map to make a selection. Manual-entry fallback fields carry clear required-field labeling.

#### Future Enhancements
Saved/favorite venues (letting a frequent host pin a go-to coffee shop to the top of results) is a reasonable v2 addition once usage data shows repeat-venue patterns — deferred for v1 to keep this a simple, stateless search-and-select tool.

---

### 12. Invite & Share Sheet

#### Purpose
Immediately after a Table is created (or on demand from Table Detail), give the host a fast way to bring people onto the Table — inviting specific Crew members directly, generating a shareable link for Open Tables, or confirming a Discover-listed Table needs no manual invite at all.

#### Primary User
The host of a Table; also any attendee re-sharing an Open Table's link with a friend, subject to the Table's visibility rules.

#### Entry Points
Automatic presentation immediately after successful `createTable` on Create Table; Table Detail's "Invite more people" action for a still-Filling Table.

#### Exit Points
Table Detail (dismissing the sheet, with or without sent invites); the OS native share sheet (when "Copy/Share link" hands off to Messages/WhatsApp/etc. outside the app).

#### UI Components
- Fraunces headline reflecting visibility ("Invite your Crew" for Crew-only, "Share this Table" for Open)
- For Crew-only Tables: multi-select Crew member list with checkboxes and a Terracotta primary button ("Send invites")
- For Open Tables: prominent "Copy link" row, "Share via..." row opening the native OS share sheet, and a live-updating headcount readout ("3 of 6 seats filled")
- For Discover-listed Tables: an informational card explaining the Table is already visible on Discover and doesn't require manual invites, with link-sharing tools still available underneath as a secondary option

#### API Calls
Table invites are recorded against the Table document created by `createTable`/`updateTable`. Inviting to a Table is distinct from Crew membership, so this screen does not call `addMember`; each invited Crew member sees the invite as a pending seat they act on via `requestSeat`/RSVP from their own Home or a push notification.

#### Validation Rules
- For Crew-only invites, at least one Crew member must be selected before "Send invites" enables
- The sheet will not let the host select more invitees than remaining open seats (headcount minus current confirmed attendees) — selection beyond that count is disabled with an inline "Only 3 seats left" note rather than a silent failure at submission time

#### Loading States
"Send invites" shows an inline skeleton-pulse while dispatch completes. "Copy link" shows a brief inline checkmark/label swap ("Copied!") rather than a loading state, since it's a synchronous local action.

#### Empty States
A host with zero Crew members sees, in place of the Crew multi-select list, a small illustration, a Fraunces headline ("No Crew yet"), one sentence of Inter body ("Share a link instead, or build a Crew from Tables you attend"), and the link-sharing tools presented directly as the primary path forward. **Clarified 2026-08 (implementation-planning review):** this link-sharing path is also the intended mechanism for `PRD.md` FR-T6's "inviting specific contacts" clause for a Closed Table host who has no Crew yet — the private invite link is capped and expires in 72 hours or at Table cap (FR-T6), so sharing it via native share directly to one specific contact (a single WhatsApp/SMS recipient, not a public post) *is* "inviting a specific contact," not a weaker, openly-shared fallback. No separate in-app contact picker is needed to satisfy FR-T6; this was previously ambiguous (the screen didn't state this explicitly) and is now resolved rather than left as an implied assumption.

#### Offline Behavior
"Copy link" and native OS share work fully offline, since the link is generated client-side from the already-created Table's ID (no network call needed). Crew-member invite dispatch queues locally and sends automatically on reconnect; "Send invites" stays enabled (never disabled to force waiting), with a toast confirming queued-vs-sent status.

#### Analytics Events
`seat_requested` is not fired from this screen (that fires when an invitee acts on the invite, not when the host sends it). This screen's dispatch action is tracked as a property on `table_created` (invite method: crew-select, link-copy, native-share, or discover-only) rather than introducing a redundant new event.

#### Accessibility Notes
Crew multi-select checkboxes announce selected/unselected state and remaining-seat constraints via live region when a selection is blocked. "Copy link"'s post-copy confirmation is announced via live region for screen reader users, not conveyed only through a visual label swap.

#### Future Enhancements
Suggested invitees based on past Crew Table attendance patterns (e.g., "these 3 usually join your Dinner Tables") is plausible once Crew history is rich enough — deferred for v1 to avoid adding predictive/algorithmic surfaces to what should be a fast, simple invite action.

---

### 13. Table Detail

#### Purpose
The canonical read/manage view of a single Table across its entire lifecycle — venue, time, headcount, attendee list with RSVP status — exposing the RSVP action itself plus host-only management actions.

#### Primary User
Any invited/interested user (to RSVP) and the host (to manage); content and available actions differ by role and by the Table's current lifecycle state.

#### Entry Points
- Home's Table Card tap
- Invite & Share Sheet dismissal (host, immediately post-creation)
- A Table invite deep link/push notification tap
- Discover surface Table Card tap
- Waitlist Screen's "View Table" link

#### Exit Points
- Live Table Screen — automatically replaces Table Detail once the Table's lifecycle transitions from Confirmed into its day-of window
- Table Chat (tapping the chat preview/entry point)
- Post-Table Rating (Table is Happened and this user hasn't rated it yet)
- Venue Picker / Create Table's edit path (host-only, while still Proposed/Filling)
- Waitlist Screen (if this user's own RSVP is Waitlisted, a "You're #2 in line" module links through)

#### UI Components
- Header block: venue name/photo, date/time, a lifecycle-state indicator distinct from RSVP chips (Proposed/Filling/Confirmed/Happened/Rated/Cancelled)
- Attendee list: avatar, name, and each attendee's RSVP status chip (Sage=Going, Terracotta Light=Requested, Gold Ochre=Waitlisted, Warm Grey=Not Going, Brick=Cancelled-Table-wide indicator)
- Single Terracotta primary action button whose label/behavior changes by viewer role and state — "Request Seat" (non-attendee, Filling), "Cancel RSVP" (Going/Requested attendee), "Manage Table" (host, Proposed/Filling/Confirmed), "Rate this Table" (any attendee, Happened/unrated)
- Table Chat preview row (last message snippet + unread badge)
- Host-only overflow menu: "Cancel Table," "Edit details," "Invite more people" (routes to Invite & Share Sheet)

#### API Calls
`requestSeat` (idempotent) for a non-attendee tapping the primary action on a Filling/Open Table; `cancelRsvp` (idempotent) for an existing attendee backing out; `confirmAttendee` (idempotent, host- or system-triggered) when a Requested seat is accepted; `cancelTable` (host-only, overflow menu); `updateTable` (host-only edit path); `reportUser`/`reportTable` and `blockUser` surfaced from a per-attendee-row overflow, safety-gated per `docs/SECURITY.md` and reachable directly from any attendee row, not buried behind multiple taps (this screen's always-visible safety-critical affordance specifically is the Live Table Screen's duress control, not this one).

#### Validation Rules
- "Request Seat" is disabled ("Table is full") once confirmed attendees equal the headcount, converting instead into "Join Waitlist" per Waitlist Screen's rules
- **`SEAT_REQUEST_CONTENTION` gets its own distinct treatment, not the "Table is full" copy.** If `requestSeat` returns this error (`API_SPEC.md` §3.1; `ARCHITECTURE.md` §6 trigger 3 — the transaction's retry budget was exhausted under heavy concurrent write load on a viral Table, not a confirmation the Table is actually full), the primary action button shows an inline, non-alarming message ("Lots of people grabbing a seat right now — try again in a second") and immediately re-enables itself for another tap, rather than converting to "Join Waitlist" or "Table is full." This distinction matters because mislabeling contention as a capacity fact would incorrectly waitlist a user who might otherwise have gotten a confirmed seat on retry.
- "Cancel RSVP" inside a short pre-Table window (e.g., under 2 hours before start) shows a confirmation dialog noting the host will be notified immediately, since late cancellations disproportionately affect a small in-person group
- Host-only "Cancel Table" always requires a confirmation dialog and, for Filling/Confirmed Tables with attendees already Going, a mandatory short reason field relayed to attendees in their cancellation notification

#### Loading States
Initial load shows a full skeleton-pulse Table Card-shaped placeholder (header block + 3–4 attendee-row placeholders, Card Cream tone). The primary action button independently shows its own inline skeleton-pulse when tapped (e.g., during `requestSeat`) without blocking the rest of the already-loaded screen.

#### Empty States
A Table with zero non-host attendees yet (freshly created, Proposed) shows the attendee list replaced with a small illustration, a Fraunces headline ("Nobody's joined yet"), one sentence of Inter body ("Share this Table to fill it up"), and a "Share this Table" primary button reopening Invite & Share Sheet.

#### Offline Behavior
Table Detail renders from local cache immediately for any previously-viewed Table, with a non-blocking "Offline — may not reflect the latest updates" banner. `requestSeat`/`cancelRsvp` actions taken offline queue locally using their `idempotencyKey`, displaying an optimistic pending ("syncing") treatment on the user's own RSVP chip until the queued call confirms on reconnect — resolving either to the expected chip or, if the Table filled up while offline, gracefully falling back to Waitlisted with an explanatory toast.

#### Analytics Events
`seat_requested` (on `requestSeat`), `rsvp_confirmed` (on a Requested seat becoming Going, whether via host-approved `confirmAttendee` or auto-approval), `report_filed` (on `reportUser`/`reportTable` submission), `block_created` (on `blockUser`), `table_cancelled` (new — on the host-only overflow menu's `cancelTable` action; properties: lifecycle state at cancellation, attendee count at cancellation — this event was missing from this screen's original spec despite `cancelTable` being one of this screen's documented API calls above, and is added here in the same pass that adds it to `FIREBASE.md`'s canonical event table, per this repository's cross-document-consistency standard).

#### Accessibility Notes
Lifecycle-state indicators and RSVP chips both carry text labels alongside color — Sage/Terracotta Light/Gold Ochre/Warm Grey/Brick are never the sole signal. Attendee rows are individually focusable with combined accessible labels (name + RSVP status). The safety/report/block overflow per attendee row is reachable via standard accessible menu semantics, not a gesture-only interaction. RTL layouts mirror the attendee avatar/chip side-swap per the design system standard.

#### Future Enhancements
A lightweight in-Table polling feature (e.g., host polls attendees on final venue choice) is a plausible extension of the attendee-list infrastructure — deferred for v1 and flagged as a Table Chat-adjacent enhancement, since it would likely live as a special chat message type rather than a new Table Detail component.

---

### 14. Live Table Screen (day-of, with duress control)

#### Purpose
The screen presented in place of Table Detail during the live window of a Table (from Confirmed through Happened) — day-of logistics (venue directions, attendee check-in, chat) plus, critically, an always-on safety affordance letting any attendee exit or signal distress without friction.

#### Primary User
Any confirmed (Going) attendee of a Table during its day-of window; the host sees the same safety affordance plus host-only day-of tools.

#### Entry Points
Automatic replacement of Table Detail once current time enters the Table's live window — defined as opening a fixed period before scheduled start (e.g., 2 hours prior, for arrival/directions use) and remaining presented until the Table transitions to Happened (system-triggered at scheduled end time, or manually closed early by the host). A push notification tap during the live window routes here directly, not to Table Detail.

#### Exit Points
- Table Chat (in-place tab/panel, not a full navigation exit)
- Post-Table Rating (automatic prompt once the Table transitions to Happened)
- The "Are you OK?" quick-exit sheet's "Leave" option — exits to Home immediately, with no requirement to interact with chat or attendees first
- **A real-time transition out to a "This Table was cancelled" state** for every non-host attendee, triggered the instant the host cancels this Confirmed Table from within the live window (see UI Components/Validation Rules below) — this is a listener-driven, in-place transition, not something the user has to pull-to-refresh or navigate away to discover

#### UI Components
**A persistent, always-visible safety affordance** — a small, calmly-styled icon/button fixed in the same on-screen position (e.g., top corner, outside the scroll area) on every single state of this screen, never inside an overflow menu, never requiring a scroll or a secondary tap to reveal. Tapping it opens the "Are you OK?" quick-exit sheet with exactly two options:
1. **"Leave this Table"** — one tap, immediately exits the user out of the Live Table Screen back to Home, with no requirement to interact with chat, attendees, or any confirmation dialog first
2. **"I need help"** — one tap, triggers a duress signal (`triggerDuressSignal`) that alerts Trust & Safety. This is decoupled from location sharing: if the user separately opted into a location share for this specific Table (via Screen 29, `createLocationShare`), that share continues independently and is not created or toggled by "I need help" — the two are deliberately distinct mechanisms behind the same affordance, per `SECURITY.md`. If no share exists yet, tapping "I need help" surfaces a one-tap follow-up offer to start one, since the moment a user reaches for help is also the moment sharing is most useful

Beyond the safety affordance: a header with venue name/address and a one-tap "Directions" action opening the device's native maps app; a horizontal attendee strip with avatars and simple "here"/"on the way" status where available; the Table Chat preview/entry tab; host-only "Mark Table as started" / "End Table early" controls; a host-only "Cancel Table" control, carried over from Table Detail's overflow menu (Screen 13) rather than newly invented here, since `cancelTable` remains callable on a Confirmed Table all the way up to the Happened transition (`PRD.md` FR-T14b) and a host emergency or venue failure is exactly as likely to surface once the group is already en route as before it.

**Host-cancels-while-en-route is a named, specified case, not a silent gap:** because attendees may already be traveling to the venue by the time this screen is showing, a host cancellation fired from here must not be treated like an ordinary pre-Table cancellation. On `cancelTable` succeeding, every non-host attendee currently on this screen sees an immediate (listener-driven, not push-dependent) full-screen transition: illustration + Fraunces headline "This Table was cancelled" + the host's short cancellation reason (mandatory, see Validation Rules) + Inter body explicitly acknowledging the in-person disruption ("Sorry — [Host] had to cancel. If you're already on your way, no need to keep heading over.") + a single "Back to Home" primary button — the same terminal treatment Waitlist Screen (Screen 16) uses for a Table cancelled out from under a waitlisted user, for visual/copy consistency. The safety affordance is **not** removed by this transition — "I need help" and "Leave this Table" remain reachable from the cancelled-state screen for a grace period (until the user navigates away), since a duress need doesn't evaporate just because the gathering itself did.

#### API Calls
A duress-signal endpoint (new — not among the seven named business endpoints in this document's ground truth; explicitly flagged as a spec gap, see Future Enhancements) that alerts Trust & Safety and, if opted in, triggers trusted-contact location sharing. `cancelRsvp` is deliberately **not** the mechanism for "Leave this Table" — leaving mid-Table for safety reasons is a distinct, lower-friction action from a pre-Table RSVP cancellation and must not carry Table Detail's confirmation-dialog treatment. `cancelTable` (host-only) is the mechanism behind the host-cancels-while-en-route case above, identical to Table Detail's call — this screen adds no new cancellation endpoint, only a distinct real-time presentation of its effect for attendees already in the live window.

#### Validation Rules
The "Leave this Table" and "I need help" actions in the quick-exit sheet have **zero validation friction by design** — no confirmation dialog, no required reason field, no re-authentication step, because any added step is itself a safety risk in a duress scenario. This is the one screen in this document where an action is deliberately built with fewer guardrails than usual, and that is an intentional, reviewed safety decision, not an oversight. The host-only "Cancel Table" control inherits Table Detail's rule exactly and does not relax it here: a confirmation dialog and a mandatory short reason field are always required, and that reason is what attendees see on the cancelled-state screen described above — precisely because a group already traveling deserves a real explanation, not less friction than Table Detail's version of the same action. Per `PRD.md` FR-T14b, a Confirmed-Table cancellation (from here or from Table Detail) carries no TableCrew-mediated payment exposure to unwind, since bill-splitting only ever begins after a Table reaches Happened.

#### Loading States
The safety affordance must render instantly and must **never** be gated behind this screen's own data-loading skeleton-pulse — it is drawn first, before venue/attendee data hydrates, specifically so a user opening this screen in distress is never staring at a loading placeholder waiting for the one control they need. All other content (venue header, attendee strip) uses the standard skeleton-pulse pattern.

#### Empty States
Not generally applicable — a live Table always has attendee/venue data by the time it reaches this screen. The attendee "here/on the way" status strip simply shows all attendees in an unknown-status neutral state (no illustration/empty-state treatment) until real check-in data arrives. The one exception is the host-cancellation transition described in Exit Points/UI Components above, which does replace this screen's normal content with a terminal "cancelled" treatment.

#### Offline Behavior
This is the most safety-critical offline case in the entire document.
- **Directions** falls back to a cached/offline map tile or the device's native maps app (which handles its own offline routing) if the live map preview can't fetch fresh data.
- **"Leave this Table"** works fully offline since it's a local navigation action with no network dependency.
- **"I need help" (duress signal)** is the one action in this document that cannot be allowed to silently queue-and-retry-later the way other offline actions do, because a delayed duress signal defeats its purpose. If the network call fails or times out within a short window (e.g., 5 seconds), the app **falls back to surfacing the device's native emergency-call capability** — a clearly-labeled "Call emergency services" option alongside a "Try again" retry for the Trust & Safety signal — rather than showing a spinner or a silent failure toast, since a user in a duress scenario without connectivity needs a working fallback in that moment, not a queued background job that might send ten minutes later.

#### Analytics Events
- `duress_signal_triggered` (new — snake_case; properties: Table ID, opted-in trusted-contact-sharing status, whether the network call succeeded or fell back to the native emergency-call path)
- `table_attended` (fired when a user's check-in/presence is confirmed during the live window)
- `table_happened` (fires on the system-triggered transition out of this screen)

#### Accessibility Notes
The safety affordance's touch target meets or exceeds standard minimum size regardless of platform Dynamic Type/font-scaling, and is exposed to screen readers with an unambiguous accessible label ("Safety options," not an icon-only unlabeled button). The "Are you OK?" sheet's two options are the first focusable elements when the sheet opens — no need to navigate past other content. **No future redesign of this screen may reduce the affordance's visibility, move it behind a menu, add a confirmation step to reaching the quick-exit sheet, or delay its render behind data loading — this constraint is binding regardless of future visual redesigns.**

#### Future Enhancements
The duress-signal backend endpoint is not yet named among this document's ground-truth API list — this spec assumes it exists as a dedicated, separate, high-priority endpoint (distinct from `reportUser`/`reportTable`, which are non-urgent) and flags this as an open item for `docs/API_SPEC.md` to formalize explicitly rather than leaving it implied. Also open: the exact trusted-contact opt-in UI (where in onboarding/Settings a user designates that contact) is referenced here and fully specified in Trusted Contact Setup (Screen 29).

---

### 15. Table Chat

#### Purpose
A per-Table group chat scoped to that Table's confirmed attendees, primarily for day-of logistics coordination ("running late," parking, "I'm here") rather than a general-purpose messaging product.

#### Primary User
Any Going attendee of a specific Table, available from Filling through Happened (read-only archive after Happened).

#### Entry Points
Table Detail's chat preview row; Live Table Screen's chat tab/panel; push notification tap on a new chat message.

#### Exit Points
Back to Table Detail or Live Table Screen (whichever presented it — this is a nested panel/tab, not a top-level destination); Table Detail's per-attendee overflow for `reportUser`/`blockUser`, surfaced via a long-press on a message rather than a separate navigation.

#### UI Components
- Standard reverse-chronological message list with sender avatar/name on messages from others
- Text composer with Terracotta send button
- Lightweight system messages inline in the stream for lifecycle events (e.g., "Priya confirmed," "Table is now full"), rendered in a visually distinct neutral style from user messages
- "Jump to latest" affordance when scrolled up in history

#### API Calls
Chat messages are written to a Table-scoped subcollection per `docs/DATABASE.md`, not through one of the seven named mutating business endpoints — sending a message is a direct Firestore write, not an idempotent Cloud Function call, since chat messages aren't safety- or payment-critical the way `requestSeat`/`confirmPayment` are. No `idempotencyKey` is assigned to this action.

#### Validation Rules
- Message length capped generously (e.g., 2,000 characters) to prevent abuse/spam pasting
- Empty/whitespace-only messages cannot be sent (composer send button stays disabled)
- Burst-spam rate-limiting applies per `docs/SECURITY.md`'s general chat-abuse guidance rather than a Table-Chat-specific rule

#### Loading States
Initial open shows 4–5 skeleton-pulse message-bubble placeholders (varying widths, Card Cream tone) rather than a spinner. Sending a message shows the new message optimistically in the stream immediately with a subtle "sending" opacity treatment resolving to full opacity on server confirmation, rather than blocking the composer.

#### Empty States
A freshly-Filling Table with no messages yet shows a small illustration, a Fraunces headline ("Say hello"), one sentence of Inter body ("Break the ice before you meet in person") — no dedicated primary button here, since the always-visible composer is the obvious next action (the one empty-state instance in this document where a redundant primary button would be noise).

#### Offline Behavior
Previously-synced messages remain fully readable offline from local cache. Composed messages while offline queue locally and display in the stream with a persistent "sending" state (not silently held off-screen) until connectivity returns, sending in original composition order; if the app is closed before reconnecting, queued messages resume sending automatically on next launch.

#### Analytics Events
No dedicated named event for chat messages in this document's ground-truth list — message send/receive is intentionally not instrumented as a named funnel event, to avoid over-tracking private conversation activity, consistent with `docs/VALUES.md`'s stance on respecting user privacy. Only Table-lifecycle-relevant system events (already covered by `table_attended`, `rsvp_confirmed`, etc.) are logged.

#### Accessibility Notes
Messages are grouped and labeled by sender for screen readers, not just visually distinguished by left/right alignment or color. System messages are announced in a distinct, less-interruptive live-region priority than new user messages. RTL layouts mirror message alignment (own messages still on the user's "leading" side per platform RTL convention) consistent with the design system's RTL standard.

#### Future Enhancements
Media/photo sharing within Table Chat (e.g., a "here's where I'm parked" photo) is a reasonable extension but deferred for v1, which is intentionally text-only to keep the moderation surface area smaller at launch — revisit once `docs/SECURITY.md`'s moderation tooling covers image content specifically.

---

### 16. Waitlist Screen

#### Purpose
Shows a user their position and status on a Table that has reached its headcount cap, and manages the promotion flow when a confirmed seat opens up.

#### Primary User
Any user whose RSVP state on a specific Table is Waitlisted.

#### Entry Points
Table Detail's "Join Waitlist" action (shown in place of "Request Seat" once a Table is full); a "You're #2 in line" module/link on Table Detail or Home; a push notification tap when the user is promoted off the waitlist.

#### Exit Points
Back to Table Detail (the same Table, reflecting current status). If promoted to Going, this screen transitions in place to a confirmation state before returning to Table Detail, rather than silently vanishing.

#### UI Components
- Fraunces headline showing the Table name and current position ("You're #2 in line for Priya's Dinner")
- One sentence of Inter body explaining promotion happens automatically if a confirmed seat opens up before the Table starts
- Simple ordered-position indicator (not a full anonymized list of other waitlisted users, to protect their privacy)
- Warm Grey/Gold Ochre-toned status chip matching the Waitlisted RSVP state
- Single Terracotta-Light (secondary-weight) "Leave Waitlist" button — deliberately not the primary Terracotta weight, since leaving is not this screen's encouraged action

#### API Calls
`requestSeat` (idempotent) is the same call used to join the waitlist in the first place — the backend determines Requested/Going vs. Waitlisted based on current headcount, per `docs/DATABASE.md`. `cancelRsvp` (idempotent) powers "Leave Waitlist," treating waitlist withdrawal as a form of RSVP cancellation rather than a separate endpoint. Promotion to a confirmed seat is driven by `confirmAttendee` (idempotent), triggered automatically by the backend when a seat frees up, not by any action on this screen.

#### Validation Rules
- "Leave Waitlist" requires no confirmation dialog, unlike Table Detail's pre-Table cancel-RSVP flow — leaving a waitlist has no impact on already-confirmed attendees
- The position number displayed is always the user's actual current queue position, never a vague "you're on the waitlist" with no position, since specificity directly affects whether a user keeps waiting or makes other plans

#### Loading States
Position number and status show a skeleton-pulse pill briefly on open while current queue state is fetched. Because position can change from other users' actions, the screen supports a subtle real-time update animation (position ticking from #2 to #1) rather than requiring a manual refresh.

#### Empty States
Not applicable in the traditional sense (a Waitlisted user always has a position by definition of being on this screen). If the waitlist entry is removed entirely (e.g., the Table was Cancelled while the user was waitlisted), the screen shows the design system's standard illustration + Fraunces headline ("This Table was cancelled") + one sentence of Inter body + a "Back to Home" primary button, matching Table Detail's own Cancelled-state treatment for consistency.

#### Offline Behavior
Cached last-known position renders immediately with an "Offline — position may have changed" banner. Real-time position updates pause while offline and resume live-updating on reconnect. "Leave Waitlist" taken offline queues via `cancelRsvp`'s `idempotencyKey` and shows an optimistic "Leaving..." state that resolves on reconnect, consistent with Table Detail's offline-action pattern.

#### Analytics Events
`seat_requested` (fired at the point of joining, same event as a direct seat request — outcome/property distinguishes Waitlisted vs. Going/Requested); `rsvp_confirmed` (fired at the point of promotion off the waitlist to a confirmed seat).

#### Accessibility Notes
Position changes are announced via live region as they update in real time ("You're now #1 in line") so screen reader users don't need to re-open the screen to notice a promotion. The Gold Ochre/Warm Grey status chip carries a text label alongside color per the general accessible-status pattern used throughout this document.

#### Future Enhancements
An optional "notify me only if I'd be promoted within X hours of the Table" filtering preference is plausible for very popular Discover Tables with long waitlists — deferred for v1, which keeps promotion notification behavior simple and unconditional (any promotion notifies immediately) to avoid adding configuration before there's evidence long waitlists are common enough to need it.

---

### 17. Post-Table Rating

#### Purpose
Collect lightweight post-Table feedback from each attendee once a Table transitions to Happened, both to close the loop on that Table's lifecycle (Happened → Rated) and to feed signal into future Discover matching quality and Trust & Safety review.

#### Primary User
Any Going attendee of a Table that has just transitioned to Happened.

#### Entry Points
Automatic prompt immediately following the Live Table Screen's transition out at Table end; Home's "Rate this Table" nudge on any Happened-but-unrated Table card; Table Detail's "Rate this Table" primary action for the same case.

#### Exit Points
Home (My Tables) on submission, typically landing back where the user was before the rating prompt interrupted them. A "Report a concern" sub-flow (safety-gated) branches off this screen into `reportUser`/`reportTable` rather than completing as a normal rating, when a user indicates something went wrong rather than simply rating experience quality.

#### UI Components
- Fraunces headline: "How was your Table?"
- Simple star or scaled emoji-face rating control (1–5) for overall experience
- Optional short free-text comment field
- Optional per-attendee "great to meet" tag-selection — lightweight positive signal only, no negative per-person public rating, to avoid enabling harassment via the rating mechanism itself
- A clearly separated, lower-emphasis "Something felt off? Report a concern" link — visually distinct from the main rating flow, not styled as a delightful/positive action, and not requiring a rating to be submitted first
- Terracotta primary button ("Submit")

#### API Calls
`submitRating` on completion of the main flow — using the platform-wide **simultaneous-reveal model**: a submitted rating is held server-side and not shown to either party until both directions have submitted or 72 hours have elapsed, whichever comes first, to prevent retaliatory rating. `reportUser`/`reportTable` if the user branches into "Report a concern" — a path that can be taken independently of, and does not require completing, the star rating.

#### Validation Rules
- Overall star/emoji rating is required before "Submit" enables; free-text comment and "great to meet" tags are optional
- The "Report a concern" path has no such requirement gating it — it is always available regardless of whether a star rating has been selected, since safety reporting should never be blocked behind an unrelated form field
- A user cannot submit more than one rating per Table — the backend enforces this, and this screen simply won't re-prompt once `submitRating` has succeeded for that Table/user pair

#### Loading States
"Submit" shows an inline skeleton-pulse while `submitRating` completes. The screen itself, typically presented immediately after a live Table ends (not from cold navigation), has no meaningful "screen load" skeleton state of its own — it renders instantly from Table/attendee data already carried over from the Live Table Screen.

#### Empty States
N/A — a single-instance form tied to one specific just-happened Table, not a list/collection view.

#### Offline Behavior
If the Table ends while the user is offline (plausible, since connectivity can be spotty at a venue), the rating prompt still surfaces locally — the Happened transition and prompt-to-rate are locally time-based, not solely server-push-based — and the completed rating queues locally via `submitRating`'s `idempotencyKey`, syncing on reconnect. The separate "Report a concern" path is treated with the same urgency as other Trust & Safety actions: if attempted offline, it shows an explicit "This needs a connection to send — we'll retry the moment you're back online" message with an active retry, rather than silently queuing invisibly, since a delayed-and-unacknowledged safety report is a worse outcome than a delayed rating.

#### Analytics Events
`rating_submitted` (existing; on `submitRating` success); `report_filed` (existing; if the user branches into the report path from this screen).

#### Accessibility Notes
The star/emoji rating control is implemented as an accessible radio-group-style control with each level individually labeled ("1 star, Poor" through "5 stars, Excellent") rather than a bare row of unlabeled icons. The "Report a concern" link has sufficient touch-target size and contrast to not read as a deliberately de-emphasized/hidden option despite its intentionally lower visual weight, since safety access should never be sacrificed for anti-friction design elsewhere on the screen.

#### Future Enhancements
Using `submitRating` data to eventually power a visible-to-hosts-only "reliability" signal (e.g., surfacing no-show patterns to hosts before they approve a `requestSeat`) is a plausible extension once enough rating volume exists — deferred and flagged as safety/fairness-sensitive enough (per `docs/VALUES.md`'s stance against manufactured pressure and `docs/SECURITY.md`'s safety-gating) that it should go through explicit human product/Trust & Safety review before being designed, rather than being assumed as an obvious v2 feature.

---

## Part 2: Discover, Crews, Trust & Safety, Payments, Account & Settings

---

### 18. Discover Feed

#### Purpose
The primary surface for finding curated Tables and people outside a user's existing Crews. Presents a personalized, ranked stream of open Tables the user could request a seat at, blending proximity, interests, and match quality.

#### Primary User
Any verified, 18+ user who has opted into Discover visibility (toggle lives in Settings; see Screen 33).

#### Entry Points
- Bottom navigation "Discover" tab (primary entry point)
- Push notification tap for a new high-quality match (deep-links into the feed, optionally scrolled to the relevant Table Card)
- Completion of onboarding, if the user opted into Discover during signup

#### Exit Points
- Tap a Table Card → Discover Table Preview (Screen 20)
- Tap the filter/search affordance → Discover Filters (Screen 19)
- Tap a host or attendee avatar on a card → that person's read-only profile view, from which Report/Block is reachable within 2 taps (see Screen 27 Entry Points)
- Switch bottom-nav tab → Crews List, Home, or Profile/Me

#### UI Components
- Vertical scroll of Table Cards, each showing activity tag, date/time, approximate location, headcount progress ("3 of 5 going"), host avatar + verification badge, attendee avatar stack (max 5 + "+N" overflow chip), and an RSVP status chip if the user already has a relationship to that Table (Sage "Going," Terracotta Light "Requested," Gold Ochre "Waitlisted")
- Persistent search/filter bar pinned to the top, opening Discover Filters
- First-time-only safety banner ("New to Discover? Read our safety basics") linking to the First-Time Safety Briefing (Screen 21); dismissible but always reachable afterward from Settings > Safety
- Pull-to-refresh gesture

#### API Calls
- `searchTables` — client queries Typesense directly for the live, low-latency feed interaction; falls back to the thin Cloud Function wrapper if the direct Typesense connection fails
- `getMatches` — supplies personalized ranking signal blended into the default (non-manually-filtered) feed ordering

#### Validation Rules
- Discover Feed only renders for users 18+ (enforced at account level at signup; this screen does not re-validate age itself)
- A location permission or a manually-set city/region is required before the feed can run a query; if neither is present, the screen redirects to a location-permission prompt rather than showing an empty feed
- Radius and other filter values passed into `searchTables` must fall within the bounds enforced by Discover Filters (Screen 19); this screen does not independently validate them

#### Loading States
Six skeleton-pulse Table Card placeholders in Card Cream tone, matching the real Table Card's layout (image/tag block, two text lines, avatar row) so the layout doesn't jump on load. No spinner is used anywhere on this screen.

#### Empty States
When a search returns zero results: illustration + Fraunces headline "No Tables nearby yet" + one line of Inter body copy ("Try widening your search or checking back soon — new Tables go up daily.") + primary Terracotta button "Widen your search," which opens Discover Filters with the radius control pre-focused.

#### Offline Behavior
The feed shows the last successfully fetched result set from local cache, read-only, with a persistent banner: "You're offline — showing your last search results." Pull-to-refresh is disabled with an inline toast ("Reconnect to refresh"). `searchTables` is not attempted, and no fallback Cloud Function call is made while offline (both require network by definition). Tapping into a cached Table Card still opens Discover Table Preview using cached data, which itself further restricts actions (see Screen 20).

#### Analytics Events
- `discover_search_performed` — fired on both the default feed load and any refinement, with params `radius_km`, `interest_tags`, `result_count`, and `degraded` (true when the Typesense-outage fallback path was used).

#### Accessibility Notes
- RSVP status chips expose their state as text to assistive technology, not color alone (e.g., "Requested" is read aloud, not inferred from Terracotta Light shading).
- Attendee avatar stacks announce a summary label ("4 attendees, 1 more not shown") rather than reading five individual unlabeled images.
- All layouts, including the avatar overflow direction, mirror correctly under RTL.
- Minimum tap target of 44×44pt on all card affordances, including the small avatar chips.

#### Future Enhancements
The spec assumes a single default feed ordering that blends `getMatches` personalization with recency/proximity, rather than separate "For You" vs. "Nearby" tabs — this is a reasoned simplification for v1 to avoid fragmenting a still-small Discover supply. If Table volume in a given market grows enough that a single blended feed feels noisy, a segmented tab (Nearby / For You) is the natural next iteration and should be revisited with real usage data rather than added speculatively now.

---

### 19. Discover Filters

#### Purpose
A refinement surface for the Discover Feed, letting the user narrow results by distance, activity type, interest tags, headcount, and time window before or during a Discover session.

#### Primary User
Any verified, 18+ user actively using Discover.

#### Entry Points
- Filter/search bar on Discover Feed
- "Widen your search" primary button on the Discover Feed empty state, opening this screen with the radius control pre-focused

#### Exit Points
- "Apply Filters" primary button → returns to Discover Feed with the new filter set applied, triggering a fresh `searchTables` call
- Back/close gesture without applying → discards in-progress changes, Discover Feed keeps its previous filter state

#### UI Components
- Radius slider (distance in km)
- Activity type selector: Coffee, Lunch, Dinner, Founder-dinners, Board Games, Hiking, Mentorship (multi-select chips)
- Interest tag multi-select chips
- Headcount range slider, hard-bounded 2–8, with activity-dependent recommended defaults pre-filled when a single activity type is selected (e.g., selecting Dinner pre-sets the slider to 4–6, selecting Coffee to 2–4) but always user-editable within the 2–8 bound
- Date/time window picker
- "Reset" text link restoring defaults
- Terracotta primary "Apply Filters" button, showing a live result-count preview above it

#### API Calls
- `searchTables` — invoked in a debounced, live fashion as filters change to power the result-count preview, and again on explicit "Apply Filters."

#### Validation Rules
- Radius must fall within platform bounds (1–50 km)
- Headcount range minimum cannot exceed maximum, and both bounds are clamped to 2–8 regardless of activity-type default
- At least one activity type is recommended but not required to submit; if none is selected, all activity types are implicitly included

#### Loading States
The result-count preview shows a skeleton-pulse placeholder (a pulsing numeral-shaped bar) while the debounced query is in flight; the rest of the form (sliders, chips) renders immediately since it reflects local, not fetched, state.

#### Empty States
If the current combination of filters would yield zero results, an inline message appears directly above the "Apply Filters" button: "No Tables match these filters yet — try widening your radius or headcount." The button remains enabled (applying zero-result filters is valid, since Discover Feed has its own empty state to handle that outcome).

#### Offline Behavior
All filter controls remain interactive and are saved to local state, but the live result-count preview is replaced with "Reconnect to see live results," and "Apply Filters" is disabled with a tooltip ("Connect to search with these filters"). The chosen filter values persist locally and are applied automatically the next time the app detects connectivity, without requiring the user to re-open this screen.

#### Analytics Events
- `discover_search_performed` — fired for the live preview and the final apply, both carrying `radius_km`, `interest_tags`, `result_count`, `degraded`.
- `filter_changed` (new) — fired once per distinct field edited (e.g., radius, activity type), to distinguish filter-tuning behavior from raw search volume in later analysis.

#### Accessibility Notes
- Sliders announce their current numeric value on every change ("Radius: 12 kilometers"), not just visually.
- Activity and interest chips behave as accessible toggle buttons with a clear pressed/unpressed state exposed to screen readers.
- Slider drag direction and the entire form layout mirror under RTL.

#### Future Enhancements
Saved filter presets (e.g., "my usual Tuesday coffee search") are a plausible v2 addition once usage data shows people re-entering the same filter combination repeatedly; not included in v1 to keep the screen simple.

---

### 20. Discover Table Preview

#### Purpose
The detail view of a single Table surfaced through Discover, shown before a user commits to requesting a seat. Surfaces enough information — host, current attendees, activity, time, approximate location, capacity — to make an informed request decision.

#### Primary User
Any verified, 18+ user browsing Discover.

#### Entry Points
- Tap a Table Card from the Discover Feed
- Deep link from a push notification about a recommended Table
- Tap a recommended Table surfaced via `getMatches` results embedded in the feed

#### Exit Points
- "Request to Join" primary button → calls `requestSeat`, then either stays on this screen with the button now showing a disabled "Requested" state and the RSVP chip updated to Terracotta Light, or returns to Discover Feed depending on entry context
- Back gesture → Discover Feed
- Tap host or attendee avatar → that person's read-only profile, with Report/Block reachable within 2 taps
- If the user already has a Requested/Waitlisted/Going relationship to this Table, a "Withdraw" affordance calls `cancelRsvp`

#### UI Components
- Expanded Table Card: activity tag, full date/time, approximate location (exact address is not shown pre-confirmation, consistent with host-side privacy norms), headcount progress bar ("3 of 5 going")
- Host summary block: avatar, name, verification badge, short bio snippet
- Attendee avatar stack (max 5 visible + "+N" overflow chip), matching the Crew Card visual pattern
- RSVP status chip if applicable
- Terracotta primary "Request to Join" button (or "Requested" disabled state, or "Withdraw" if already requested/waitlisted/going)
- A small report/flag icon adjacent to the host's name, satisfying the 2-tap Report/Block reachability requirement from any screen showing another person

#### API Calls
- `requestSeat` (idempotent, requires client-generated `idempotencyKey`) — sends the join request.
- `cancelRsvp` (idempotent) — withdraws an existing Requested/Waitlisted/Going relationship.

#### Validation Rules
- "Request to Join" is disabled or hidden if the Table's status is Cancelled or Happened
- If the Table is at full capacity (Confirmed and headcount met), the button instead reads "Join Waitlist," reflecting that `requestSeat` may place the user in a Waitlisted state rather than Requested — copy adapts accordingly
- A `SEAT_REQUEST_CONTENTION` response from `requestSeat` gets the same distinct, re-enable-and-retry treatment specified on Table Detail (Screen 13) rather than being mislabeled as "Table is full" — this is the same underlying endpoint and error, and the two entry points must not diverge on how they present it
- A user cannot request a seat on their own hosted Table (button is not shown at all in that case; this screen instead shows the host-management view, which is the Live Table Screen's territory, not duplicated here)
- Headcount bounds (2–8) are enforced server-side; this screen only reflects the resulting state, it does not independently gate on headcount

#### Loading States
Skeleton-pulse placeholder for the full expanded card (host block, attendee stack, action button area) while the Table detail is fetched, in Card Cream tone.

#### Empty States
Not a data-list screen, so no traditional empty state applies. If the Table was cancelled or removed between the user tapping it and the detail loading, the screen shows: illustration + Fraunces headline "This Table is no longer available" + Inter body ("It looks like this one was cancelled or filled up.") + primary button "Back to Discover."

#### Offline Behavior
If reached from a cached Discover Feed, the preview renders read-only from the cached card data with a banner "You're offline — some details may be out of date." "Request to Join" behaves exactly like Table Detail's (Screen 13) primary action, not more conservatively — a divergence here was an earlier drafting inconsistency, corrected in this pass: tapping it while offline queues `requestSeat` locally using its `idempotencyKey`, shows the optimistic pending ("syncing") treatment on the RSVP chip, and resolves on reconnect to the server-confirmed outcome (Going/Requested/Waitlisted). This is required, not just permitted, by `PRD.md` NFR-14 ("RSVP and check-in actions taken offline are honored with their original client timestamp once synced... to preserve fair waitlist ordering") and by `API_SPEC.md` §2's idempotency-key design, which exists specifically for a flaky-connection retry of a capacity-mutating call like this one — blocking the action outright offline would silently violate both. "Withdraw" (`cancelRsvp`) follows the identical queue-and-sync pattern.

#### Analytics Events
- `seat_requested` — fired on a successful `requestSeat` call.
- `table_preview_viewed` (new) — fired on screen view, useful for measuring Discover funnel drop-off between preview and request that isn't otherwise captured.

#### Accessibility Notes
- The attendee avatar stack's overflow announces a full count, not just "+2" as a bare visual chip.
- The headcount progress bar exposes a text equivalent ("3 of 5 spots filled"), not just a visual fill bar.
- Avatar stack overflow direction and the whole layout mirror under RTL.

#### Future Enhancements
Showing an approximate vs. exact location pre-confirmation is a deliberate privacy choice for the host; a future enhancement could let hosts opt into showing exact location earlier for Tables in well-known public venues (e.g., a named coffee shop) where there's no real safety benefit to withholding it. Not implemented in v1 to keep the privacy default uniformly conservative.

---

### 21. First-Time Safety Briefing

#### Purpose
A one-time interstitial shown before a user's first real engagement with Discover (first feed visit or first seat request, whichever comes first), explaining verification norms, public-meeting-spot expectations, the trusted contact feature, and that reporting/blocking are always close at hand.

#### Primary User
New Discover users, 18+, already account-verified but new to meeting curated strangers through the product.

#### Entry Points
- Auto-triggered the first time a user opens Discover Feed or attempts their first `requestSeat` action.
- Manually reopenable from Settings > Safety at any time afterward.

#### Exit Points
- "Got it, continue" primary Terracotta button → dismisses and resumes the action that triggered it (opening the feed, or completing the pending seat request).
- Secondary link "How location sharing works" → Trusted Contact Setup (Screen 29) in its no-Table-context explainer mode (see Screen 29), returning here afterward to complete the acknowledgment. This is deliberately an explainer, not a live setup flow — location sharing is created per-Table (`createLocationShare`), and no specific Table exists yet at this point in the flow.
- Secondary text link "Learn more about Trust & Safety" → a longer-form safety help article (outside this document's numbered screen set).

#### UI Components
- Short multi-section scroll (not a swipe-required carousel, to avoid gating comprehension behind a specific gesture): illustration, Fraunces section headlines, one sentence of Inter body copy per section.
- Sections cover: verification basics, meeting in public places for early Tables, the trusted-contact live-location feature, and "reporting or blocking anyone is always two taps away."
- Terracotta primary "Continue" button fixed at the bottom, always reachable without requiring the user to scroll through every section first (comprehension is encouraged, not gated, to avoid feeling like a forced gauntlet).

#### API Calls
None required to render — content is static and bundled with the app. Acknowledgment is persisted as a simple flag on the user's own profile document, written directly by the client (no dedicated Cloud Function exists for this in the fixed API list; treated as a lightweight profile-field update consistent with other simple preference writes).

#### Validation Rules
The client gates the *first* `requestSeat` attempt behind this acknowledgment flag being true — if a first-time user's first action is a direct deep-linked seat request, the briefing is shown first and the request proceeds only after "Continue" is tapped. This is a client-side UX gate, not a server-enforced rule; the server does not reject `requestSeat` calls based on briefing-acknowledgment state.

#### Loading States
Effectively none — content is bundled and renders immediately. If a snippet listing the user's currently-active location shares (across any live Tables) is shown inline, that small section alone shows a brief skeleton-pulse while it fetches.

#### Empty States
Not applicable; this is a static informational screen, not a data-driven list.

#### Offline Behavior
Fully available offline, since all content is bundled with the app and requires no network call to render or acknowledge (the acknowledgment write to the profile is queued and synced like any other simple preference change). If the user's originating action (e.g., `requestSeat`) itself requires connectivity, that action's own offline handling applies once "Continue" is tapped.

#### Analytics Events
- `safety_briefing_viewed` (new) — fired on screen presentation.
- `safety_briefing_acknowledged` (new) — fired when "Continue" is tapped.

#### Accessibility Notes
- Full screen-reader support with proper heading hierarchy per section.
- "Continue" is always focusable and activatable regardless of scroll position — it is never hidden until the user swipes through every panel.
- Layout mirrors under RTL, including illustration placement.

#### Future Enhancements
None outstanding; this screen is intentionally minimal and static by design.

---

### 22. Crews List

#### Purpose
Shows all Crews — persistent friend groups — the user is currently a member of, distinct from one-off Discover Tables, as the home base for ongoing group coordination.

#### Primary User
Any user, whether they belong to zero, one, or many Crews.

#### Entry Points
- Bottom navigation "Crews" tab.
- Push notification tap for `crew_table_scheduled`, deep-linking here (then into the relevant Crew Detail).

#### Exit Points
- Tap a Crew Card → Crew Detail (Screen 24).
- "Create Crew" primary button → Create Crew (Screen 23).

#### UI Components
- List of Crew Cards, each a horizontally-scrollable avatar stack (max 5 visible + "+N" overflow chip), Crew name, and a one-line activity snippet ("Table proposed for Sat" / "Table happened 3 days ago" / "No Tables yet").
- Terracotta primary "Create Crew" button, positioned as a persistent top-right action or FAB.
- Lightweight search field if the user has more than ~8 Crews (keeps the screen usable at scale without over-engineering for the common case of a handful of Crews).

#### API Calls
No dedicated named Cloud Function exists for "list my Crews" in the fixed API list; this is a direct Firestore read of the Crews the user is a member of, consistent with the client-direct read pattern used elsewhere (e.g., Discover's direct Typesense queries).

#### Validation Rules
Read-only screen; no input validation applies. Crew Cards for Crews the user has left no longer appear (removal handled server-side on `leaveCrew`/`removeMember`).

#### Loading States
Skeleton-pulse Crew Cards (an avatar-stack-shaped placeholder row plus two text bars) in Card Cream tone, four to six placeholders depending on viewport height.

#### Empty States
Illustration + Fraunces headline "No Crews yet" + Inter body "Crews are your people — start one so you're not re-sending the same invite every time you want to grab dinner." + primary Terracotta button "Create Crew."

#### Offline Behavior
Shows the last cached Crew list, read-only, with a banner "You're offline — showing your saved Crews." Tapping into a Crew Detail from cache still works read-only; "Create Crew" remains tappable but the resulting screen blocks actual submission offline (see Screen 23).

#### Analytics Events
- `crews_list_viewed` (new) — low-priority screen-view event, useful for Crews-feature funnel analysis; not in the fixed list but follows its `snake_case` convention.

#### Accessibility Notes
- Crew Card avatar-stack overflow chip announces "and N more members," not just a bare "+3" glyph.
- Horizontal avatar-stack scroll direction mirrors under RTL.
- Crew Cards are single, clearly-bounded tap targets (the whole card navigates, not just the name text).

#### Future Enhancements
No sorting/pinning of favorite Crews is included in v1; if users accumulate many Crews, a "pin to top" or most-recently-active sort is a natural follow-up once real usage patterns emerge.

---

### 23. Create Crew

#### Purpose
A short form for starting a new persistent Crew: name, optional photo, and initial members.

#### Primary User
Any verified user wanting to formalize a recurring group (e.g., people they keep wanting to grab dinner with).

#### Entry Points
- Crews List "Create Crew" button.
- A post-Table prompt suggesting "Start a Crew with people from this Table" (surfaced from the Live Table Screen or Post-Table Rating flow, Screens 14/17).

#### Exit Points
- "Create Crew" primary button → calls `createCrew` (and subsequent `addMember` calls for each invitee not bundled into the initial payload) → navigates to the new Crew's Crew Detail screen.
- Back/cancel → if any field has been filled in, a confirmation dialog ("Discard this Crew?") appears before leaving; otherwise exits immediately.

#### UI Components
- Crew name text field.
- Optional Crew photo picker.
- Member picker: searchable list of existing connections (people the user has shared a Table or Crew with previously), each result showing name + verification badge, tap to add as a chip in a "selected members" row.
- Terracotta primary "Create Crew" button, disabled until validation passes.

#### API Calls
- `createCrew` (idempotent, requires `idempotencyKey`).
- `addMember` (idempotent) — called once per invitee if members are added after initial creation rather than bundled into the `createCrew` payload.

#### Validation Rules
- Crew name is required, 1–40 characters.
- At least one other member must be selected — a Crew implies more than one person by definition.
- Blocked users never appear in the member-search results in either direction (silent enforcement, consistent with block behavior elsewhere), so no explicit "can't add this person" error state is needed.
- A soft cap of 20 members per Crew is enforced (this number is not specified elsewhere in existing product documentation; it is a reasoned default to keep group coordination and Crew Chat usable, and is flagged in Future Enhancements as a decision that should get explicit product sign-off).

#### Loading States
Member search results show a skeleton-pulse placeholder list while the query runs. The "Create Crew" button shows a disabled, pulsing "Creating…" label state during submission rather than a spinner.

#### Empty States
If a member search yields no matches, a small inline row reads "No matches — try a different name" (not a full illustrated empty state, since this is a small in-context sub-search, not a primary screen).

#### Offline Behavior
The form remains fully fillable offline and the draft (name, photo, selected members) is retained locally, but "Create Crew" is disabled with the message "Connect to create your Crew" — Crew creation establishes real social/membership state shared with other people and is not treated as safe to queue silently.

#### Analytics Events
- `crew_created` (new) — fired on a successful `createCrew` call; this is a natural, expected event that is not yet in the fixed list and is added here following the `snake_case` convention.

#### Accessibility Notes
- Member picker rows expose name and verification status to screen readers as a single coherent label, not fragmented across separate elements.
- Selected-member chip row mirrors under RTL.

#### Future Enhancements
The 20-member cap and the "creator is admin by default" assumption (see Screen 24) are both open product decisions that should be explicitly confirmed rather than inherited silently from this spec.

---

### 24. Crew Detail

#### Purpose
The home screen for a single Crew: roster, shared Table history, upcoming Tables, and the entry point into that Crew's persistent chat.

#### Primary User
Any member of the Crew.

#### Entry Points
- Tap a Crew Card from Crews List.
- Push notification deep link (e.g., `crew_table_scheduled`).
- Tap the Crew name/avatar header from within Crew Chat.

#### Exit Points
- "Open Chat" button → Crew Chat (Screen 25).
- "Schedule a Table" primary button → Recurring Table Schedule Setup (Screen 26) for a recurring series, or the ad-hoc Create Table flow (Screen 10) for a one-off Table.
- Tap a member avatar → that person's profile, with Report/Block reachable within 2 taps.
- Overflow menu → "Leave Crew" (confirmation dialog → `leaveCrew`) or "Manage Members" (`addMember`/`removeMember`).

#### UI Components
- Crew header: name, photo, full member roster (not truncated to 5 here, unlike the Crews List's compact Crew Card — this is the detail context where the full list is expected).
- Upcoming Tables section: cards showing Proposed/Filling/Confirmed status chips.
- Table history section: past Tables with their terminal Rated (or Cancelled) status chip.
- Terracotta primary "Schedule a Table" button.
- Secondary "Open Chat" button.
- Overflow (kebab) menu: Manage Members, Leave Crew.

#### API Calls
- `addMember`, `removeMember`, `leaveCrew` (all idempotent where applicable).
- Links out to `scheduleRecurringTable` (via Screen 26) and `createTable` (via Screen 10's ad-hoc flow) rather than calling them directly on this screen.

#### Validation Rules
- Only the Crew's creator can `removeMember` other members; any member can `leaveCrew` for themselves. This creator-as-admin model is a reasoned default — the product facts provided don't specify a formal roles system — and is flagged in Future Enhancements as needing explicit product confirmation before it hardens into shipped behavior.
- A user cannot `removeMember` themselves; they must use `leaveCrew` instead, which carries a distinct confirmation copy ("You'll need to be re-invited to rejoin this Crew").

#### Loading States
Skeleton-pulse placeholders for the member roster row and the Table history/upcoming lists, in Card Cream tone.

#### Empty States
- No Table history yet: illustration + Fraunces headline "No Tables yet with this Crew" + Inter body ("Get the group together — schedule your first one.") + primary button "Schedule your first Table."
- No upcoming Tables (but history exists): a smaller inline empty row ("Nothing on the calendar yet") rather than a second full illustration, to avoid visual clutter when the screen already has content above it.

#### Offline Behavior
Cached Crew Detail is viewable read-only, including roster and history. "Schedule a Table," "Manage Members," and "Leave Crew" are all disabled with an offline banner, since each changes real membership or commitment state that needs live server confirmation. "Open Chat" remains tappable — Crew Chat has its own offline message queue (Screen 25) and doesn't require the Crew Detail data itself to be fresh.

#### Analytics Events
- `crew_table_scheduled` — fired when a scheduling flow launched from this screen completes successfully.
- `member_added`, `member_removed` (new) — fired on successful roster changes.

#### Accessibility Notes
- Roster rows expose an "Admin" label via accessible text (not just a badge icon) where the creator-as-admin model applies.
- Header layout and status chip rows mirror under RTL.

#### Future Enhancements
The creator-as-sole-admin model is an open decision; a future iteration may need co-admin support for Crews where the original creator becomes inactive. This should be resolved with product input before the permission model is treated as final.

---

### 25. Crew Chat

#### Purpose
A persistent group chat scoped to a single Crew, used for coordination between Tables (picking a date, sharing logistics, casual conversation) — distinct from any single Table's ephemeral coordination.

#### Primary User
Any member of the Crew.

#### Entry Points
- "Open Chat" button on Crew Detail.
- Push notification tap for a new Crew message.

#### Exit Points
- Back → Crew Detail.
- Tap a member's avatar next to a message → that person's profile, with Report/Block reachable within 2 taps.
- Tap a shared Table card inline in the chat → that Table's detail screen (Discover Table Preview or the Live Table Screen, depending on the Table's current lifecycle state).

#### UI Components
- Chronological message bubble list, own messages right-aligned (left-aligned under RTL), others' left-aligned with avatar + name.
- Text input field with a Terracotta send button.
- Attachment affordance for sharing a Table card inline (renders as a compact Table Card preview within the message stream).
- Per-message delivery state indicator: Pending (clock icon), Sent (single check), Failed (red exclamation, "tap to retry").
- Mini Crew header at the top (avatar stack + name) linking back to Crew Detail.

#### API Calls
No dedicated named Cloud Function exists for sending chat messages in the fixed API list; messages are written directly to a Crew-scoped messages subcollection by the client, consistent with the client-direct write/read pattern used elsewhere in this spec (e.g., Discover's direct Typesense queries, Settings' direct preference writes).

#### Validation Rules
- Messages cannot be empty or whitespace-only.
- A soft character cap of 2,000 characters per message is applied (a reasoned default, not specified elsewhere, flagged as an assumption).
- A lightweight client-side send-rate throttle guards against accidental spam bursts (e.g., rapid repeated taps); no formal rate-limit policy is specified in existing product docs, so this is noted as an assumption rather than a hard rule.

#### Loading States
Skeleton-pulse message-bubble placeholders (varying widths) on initial thread load; a smaller skeleton-pulse row appears at the top of the list when paginating in older messages via scroll-up.

#### Empty States
Illustration + Fraunces headline "Say hello to your Crew" + Inter body ("This is your space to plan the next one — or just catch up.") — no primary button is included here, since the always-visible text input is itself the call to action; a redundant button would be noise.

#### Offline Behavior
Genuinely offline-tolerant, unlike most other screens in this document:
- Messages composed while offline are placed in a local send queue and immediately rendered with a Pending state (clock icon).
- On reconnect, queued messages are sent in original composition order automatically.
- Once acknowledged by the server, a message's state updates to Sent (single check).
- If a message fails to send after automatic retries (e.g., persistent connectivity failure, or server-side moderation rejection), it shows a Failed state with a red indicator and "Tap to retry."
- The send queue persists across app restarts so nothing composed offline is silently lost.
- A persistent top banner reads "You're offline — messages will send when you're back online" whenever the queue is non-empty and the device is offline.

#### Analytics Events
- `crew_message_sent` (new) — fired once a queued or live message is confirmed sent.
- `crew_message_failed` (new) — fired when a message ultimately fails after retries.

#### Accessibility Notes
- Each message bubble exposes sender name, timestamp, and content as one coherent accessible label.
- Pending/Sent/Failed states are announced via accessible status text ("message pending," "message failed, tap to retry"), never conveyed by color alone.
- Bubble alignment (own vs. others') mirrors correctly under RTL.

#### Future Enhancements
Read receipts (seen-by indicators) are not included in v1; a message character cap of 2,000 and the send-rate throttle are both reasoned defaults flagged for explicit product/policy confirmation rather than treated as settled.

---

### 26. Recurring Table Schedule Setup

#### Purpose
Lets a Crew set up a recurring Table series (e.g., "Dinner every other Thursday") in one flow, rather than manually recreating a one-off Table each time.

#### Primary User
A Crew member, most likely the Crew's creator/admin (see the role assumption noted in Screen 24).

#### Entry Points
- Crew Detail "Schedule a Table" → "Make it recurring" option.
- Crew Detail overflow menu, as a dedicated entry.

#### Exit Points
- "Confirm Schedule" primary button → calls `scheduleRecurringTable` → returns to Crew Detail, now showing the newly generated upcoming Tables in the Proposed state.
- Back/cancel → discards the in-progress form.

#### UI Components
- Activity type selector (Coffee, Lunch, Dinner, Founder-dinners, Board Games, Hiking, Mentorship), each pre-populating a recommended headcount default (e.g., Dinner → 4–6, Coffee → 2–4, Board Games/Hiking → 4–8) while remaining editable within the hard 2–8 range.
- Recurrence pattern picker: weekly / biweekly / monthly, specific day of week, specific time.
- Location field, with an explicit "Decide per occurrence" option for series where the venue varies each time.
- End condition selector: fixed number of occurrences, an end date, or "Until I cancel this series" (an explicit choice, not a silent default, to avoid accidentally generating an unbounded series).
- Terracotta primary "Confirm Schedule" button.
- A preview list of the next three upcoming occurrence dates, recalculated live as the pattern changes.

#### API Calls
- `scheduleRecurringTable` (idempotent, requires `idempotencyKey`). Individual Table instances in the series are assumed to be generated server-side (a fan-out from the recurring schedule into discrete Tables reachable via the normal Table lifecycle), rather than the client calling `createTable` once per occurrence — this server-side fan-out behavior is an assumption about implementation, flagged in Future Enhancements as something that should be confirmed against `docs/API_SPEC.md`. Per `PRD.md` FR-T14c, each generated occurrence is a fully normal Table subject to FR-T14/FR-T14a's own viability checks and cancel-suggestion flow independent of every other occurrence — a single Thursday failing to reach quorum (or being cancelled outright) has no effect on the recurring template or on any future occurrence already scheduled to generate, and this screen's own "Confirm Schedule" action is not re-invoked or re-validated when that happens.

#### Validation Rules
- Headcount must stay within the 2–8 hard range regardless of the activity-dependent default shown.
- The recurrence pattern must produce at least one valid future occurrence before "Confirm Schedule" is enabled.
- An end condition is required — "Until I cancel this series" must be explicitly selected rather than assumed, so a series is never silently unbounded.
- A location must be provided, or the explicit "Decide per occurrence" flag set — the field cannot be left simply blank.

#### Loading States
The "next 3 dates" preview shows a skeleton-pulse placeholder while recalculating after any pattern change.

#### Empty States
Not a data-list screen. If the Crew has no members besides its creator, an inline warning appears above the form: "Invite Crew members before scheduling a recurring Table," linking to Crew Detail's member management.

#### Offline Behavior
The form is fully fillable and the draft is retained locally, but "Confirm Schedule" is disabled with a banner "Connect to schedule this series" — scheduling creates real recurring commitments across multiple people's calendars and is treated as too consequential to queue silently, consistent with how Create Crew and Crew Detail's membership actions are handled offline.

#### Analytics Events
- `crew_table_scheduled` — fired on success, with recurrence metadata (cadence, occurrence count) included as event params.

#### Accessibility Notes
- Date/time controls use standard platform-native accessible pickers.
- The recurrence summary is read to screen readers as one complete sentence ("Repeats every other Thursday at 7 PM, ending after 6 Tables") rather than as disconnected field values.
- Form layout mirrors under RTL.

#### Future Enhancements
The assumption that individual Table instances are generated server-side from the recurring schedule (rather than client-driven) should be confirmed and formally documented in `docs/API_SPEC.md`. The admin-only scheduling permission mirrors the same open role-model question flagged in Screen 24.

---

### 27. Report Flow

#### Purpose
Lets a user report another user, a Table, or a no-show. This is a safety-critical screen and must be reachable within 2 taps maximum from any screen showing another person.

#### Primary User
Any user.

#### Entry Points
This screen's entry points are the concrete demonstration of the 2-tap requirement:
1. Tap the flag/overflow icon on a person's avatar or profile chip — available on Discover Table Preview, Crew Detail's roster, Crew Chat message rows, any read-only profile view, and the Live Table Screen's roster — this is tap one.
2. Tap "Report" from the resulting action sheet — this is tap two, landing directly on this screen.
A longer path also exists via Profile/Me → Settings → Safety → Report Someone, for users who want to file a report without a specific in-context trigger; this does not replace the 2-tap in-context path, it supplements it.

#### Exit Points
- "Submit Report" primary button → calls `reportUser` or `reportTable` (context-dependent) and optionally `blockUser` if the inline block toggle is checked → a confirmation screen ("Thanks, we've got this — our Trust & Safety team will review this report.") → returns to the originating screen.
- Cancel/back → returns to the originating screen with no action taken.

#### UI Components
- Reason selection list, presented as a radio-button group: Harassment, Inappropriate content/behavior, Safety concern, No-show, Fake profile/spam, and — visually and semantically separated by a divider, not buried among the generic reasons — "This happened outside the app," mapped to the distinct reason code `off_platform_stalking`, with helper subtext: "For harassment or stalking that continued after a Table, off the platform — this gets reviewed differently and faster."
- Free-text detail field.
- Optional evidence/screenshot attachment.
- Inline "Also block this person" toggle, pre-checked by default when Harassment or the off-platform reason is selected, present-but-unchecked for lower-severity reasons.
- Terracotta primary "Submit Report" button.

#### API Calls
- `reportUser` or `reportTable`, depending on report context.
- `blockUser` (idempotent semantics expected, consistent with other mutating calls), if the inline block toggle is checked.
- If the report concerns a no-show on a specific Table, this contributes to that Table's no-show marking, which uses single-source weighting — a lone host's mark carries reduced weight without corroboration, so this screen's confirmation copy does not promise that a single report guarantees punitive action against the reported user.

#### Validation Rules
- A reason must be selected before "Submit Report" is enabled.
- If `off_platform_stalking` is selected, the free-text detail field becomes required (not optional), since expedited human review needs enough context to act quickly.
- The evidence attachment is optional but recommended, with helper copy encouraging it for off-platform or harassment reasons specifically.
- The reporting entry point is never surfaced on a user's own avatar/profile, preventing self-reports by construction rather than by a validation error message.

#### Loading States
The "Submit Report" button shows a disabled, pulsing "Submitting…" label during the call; no card-list skeleton states are needed since this is a single form.

#### Empty States
Not applicable — this is a form screen, not a data list.

#### Offline Behavior
Reporting is blocked entirely offline rather than queued: "You're offline. Reports need a live connection to reach our Trust & Safety team — please try again once you're connected." This is deliberate — a silently-queued report risks being delayed or lost for a safety-critical action. Regardless of connectivity, the screen always displays a static, non-gated line of text: "If you're in immediate danger, contact local emergency services," since that guidance must never be hidden behind a network check.

#### Analytics Events
- `report_filed` — with a `reason` param distinctly capturing `off_platform_stalking` alongside the other reason codes.
- `block_created` — fired if the inline block toggle was used, carrying only `blocker_id`, never the blocked user's ID, per the platform-wide silent-blocking policy.

#### Accessibility Notes
- The reason list is a proper radio-button group with a sensible focus order.
- The off-platform option is distinguished by more than color — a divider, a distinct label, and its own screen-reader group heading ("Off-platform harassment") separate from the general "Reasons" group.
- Form layout mirrors under RTL.

#### Future Enhancements
The rule that the block toggle defaults to pre-checked for higher-severity reasons is a UX heuristic, not an explicitly specified policy — it should get direct sign-off from the Trust & Safety function before being treated as final behavior, since default-checked destructive actions deserve deliberate review.

---

### 28. Block Confirmation

#### Purpose
A confirmation step before finalizing a block action, making the silent nature of blocking explicit to the user taking the action (never to the blocked person).

#### Primary User
Any user.

#### Entry Points
- "Block" tapped from the same action sheet used for Report Flow (Screen 27) on any person's avatar/profile — satisfying the same 2-tap reachability requirement.
- An in-context "What does blocking do?" link from within the Report Flow's block toggle, for users who want to understand the action before checking that box.

#### Exit Points
- "Block" primary button (destructive-toned) → calls `blockUser` → success toast "Blocked. They won't be notified." → returns to the originating screen, with the blocked user's content now hidden from the current view (e.g., removed from a Discover feed already on screen, or a chat roster).
- "Cancel" → dismisses with no action taken.

#### UI Components
- Modal/sheet with Fraunces headline "Block this person?"
- Inter body copy plainly stating what blocking does: they will not be told; they will no longer appear in the blocker's Discover results; they cannot request to join the blocker's Tables again; if the two of you share a Crew, that Crew membership is unaffected (removing membership is a separate, deliberate action), but neither of you will see the other's messages in that Crew's chat going forward — per `docs/SECURITY.md`'s "Reporting and Blocking" section, blocking suppresses direct messaging between the two of you everywhere, including inside a shared Crew, not just in Discover/direct contexts.
- Terracotta-styled destructive primary "Block" button (the design system's Brick tone, otherwise reserved for the Cancelled status chip, is the closest existing "serious" accent and is used here for the destructive action styling).
- Secondary "Cancel" text button.

#### API Calls
- `blockUser`.

#### Validation Rules
- The block entry point is never surfaced on a user's own profile, preventing self-blocking by construction.
- Requires this explicit confirmation step — no single-tap block action exists anywhere in the product.
- If the target is a fellow member of a shared Crew, an additional inline sentence clarifies that shared Crew membership persists (leaving is a separate, deliberate action), but messages between the two of you in that Crew's chat are mutually hidden from this point on, per `docs/SECURITY.md`.

#### Loading States
The "Block" button shows a disabled, pulsing "Blocking…" state during the call.

#### Empty States
Not applicable — this is a single-purpose confirmation modal.

#### Offline Behavior
`blockUser` is blocked entirely offline rather than queued, since it must propagate immediately to Discover matching eligibility and Table-join eligibility: "Connect to block this person. This can't be done offline."

#### Analytics Events
- `block_created` — carrying only `blocker_id`, consistent platform-wide with never recording the blocked user's ID in analytics (the backend of course still stores the actual block relationship for enforcement purposes; it is simply excluded from the analytics event payload).

#### Accessibility Notes
- The modal traps focus and maps the standard dismiss gesture (escape/back) to "Cancel."
- The full explanatory copy is announced by screen readers before the "Block" button becomes the next focus stop, so the consequence is understood before the action is available.
- Modal layout mirrors under RTL.

#### Future Enhancements
The interaction between blocking and shared Crew membership is now resolved (see `docs/SECURITY.md`'s "Reporting and Blocking" section): membership persists, but messaging between the two parties is mutually suppressed in that Crew's chat, the same as everywhere else blocking applies. What's still open: whether a blocker should get an inline, low-key affordance from this screen to also leave a shared Crew in one step (today that remains a separate action from Crew Detail), which is a product-scope decision, not a safety-correctness gap.

---

### 29. Trusted Contact Setup

#### Purpose
Lets a user share their live location with someone they trust — a Crew member or an external phone contact — for the duration of one specific Table. **Revised 2026-08 (architecture readiness pass):** this is deliberately **not** a persistent saved-contact profile setting. Per `SECURITY.md` and `API_SPEC.md`'s `createLocationShare`/`revokeLocationShare` (§3.4), a stale "always share with X" toggle is itself a privacy risk if the user forgets it's on, so every share is its own scoped, explicit, per-Table opt-in with no standing default. The screen therefore renders in two distinct modes depending on whether it's opened with a specific Table in context.

#### Primary User
Any user with an active or upcoming Table, especially first-time Discover users and safety-conscious users preparing to meet someone new in person.

#### Entry Points
- **In-Table mode** (has `tableId` context — the common case): Live Table Screen's "share my location" affordance (Screen 14), or a pre-Table checklist prompt from Table Detail (Screen 13) shortly before a Confirmed Table's start time.
- **Explainer mode** (no `tableId` context): First-Time Safety Briefing (Screen 21) link; Settings > Safety section, which also lists any currently-active shares across live Tables and lets the user revoke them from one place regardless of which Table created them.

#### Exit Points
- **In-Table mode:** "Start Sharing" → calls `createLocationShare` → returns to the originating screen with an active-share confirmation. An existing active share for this Table shows a "Stop Sharing" control instead → calls `revokeLocationShare` → returns to originating screen.
- **Explainer mode:** "Got it" → returns to Settings or the Safety Briefing. Tapping "Stop Sharing" next to any listed active share revokes it in place without leaving the screen.

#### UI Components
- **In-Table mode:** a contact-type toggle — "Share with a Crew member" (picker limited to Crew members shared with the caller on this Table) vs. "Share with someone else" (external phone number field, E.164-validated) — mirroring `createLocationShare`'s `contactType: "crew_member" | "external_sms"` request shape exactly, so the UI never offers a combination the API would reject. A plain-language explainer block (Inter body, not legal boilerplate) stating exactly what is shared (live location only — not messages, not history), for how long (from now until the Table ends, is cancelled, or sharing is manually stopped, capped at 6 hours), and that the recipient gets a one-time link, not app access. Terracotta primary "Start Sharing" button.
- **Explainer mode:** the same plain-language explainer block, plus (if any exist) a list of the user's currently-active shares across any live Tables, each with the Table name, recipient (Crew member name, or "external contact" — the phone number itself is never re-displayed once sent), time remaining, and a "Stop Sharing" action. No contact-picker form is shown in this mode, since there is no Table to scope a new share to.

#### API Calls
`createLocationShare` **[idempotent]**, `revokeLocationShare` (in-Table mode); a read of the caller's own currently-active `locationShares` across Tables they're an attendee of, for the explainer mode's status list (no dedicated list endpoint — the client queries its own accessible `tables/*/locationShares` documents directly, consistent with the read-your-own-data pattern used elsewhere).

#### Validation Rules
- Exactly one of Crew-member selection or external phone number must be provided, never both, never neither (mirrors `createLocationShare`'s `invalid-argument` check).
- External phone number must pass E.164 format validation and cannot equal the caller's own verified number.
- A share can only be created for a Table the caller holds a `confirmed` RSVP on (`TABLE_NOT_LIVE_ELIGIBLE` otherwise) — in-Table mode is simply not reachable from a Table where this doesn't hold, so this surfaces primarily as a defensive check if state changes mid-flow (e.g., an RSVP is revoked in another tab).
- Only the original sharing user can revoke their own share (`permission-denied` otherwise) — not applicable client-side since only that user's own shares are ever listed to them.

#### Loading States
Skeleton-pulse over the active-share status card/list while it fetches; the contact-type toggle and picker render immediately since they depend only on already-loaded Crew membership data.

#### Empty States
**Explainer mode only**, when no shares are currently active: illustration + Fraunces headline "No active location shares" + Inter body explaining the feature's value ("When you join a Table, you can share your live location with someone you trust — just for that gathering.") — no button here, since starting a share requires a specific Table and none is in context; the user is directed back to an upcoming Table instead.

#### Offline Behavior
Any existing active-share list is viewable from cache, read-only. "Start Sharing" and "Stop Sharing" are disabled with the banner "Connect to share or stop sharing your location" — both actions have real-world side effects on a third party (an SMS send, or a revoke that should take effect immediately) that must not be queued silently while offline, consistent with `SCREEN_SPECIFICATIONS.md`'s general rule that irreversible/third-party-affecting actions block rather than queue offline.

#### Analytics Events
- `location_share_created`, `location_share_revoked` (renamed from the earlier `trusted_contact_added`/`trusted_contact_removed` naming to match the per-Table model — see `docs/FIREBASE.md` §2.9). The earlier `trusted_contact_toggle_changed` event no longer applies, since there is no standing default-share toggle in this model.

#### Accessibility Notes
- The phone field uses the platform's phone-appropriate keyboard/input type.
- The explainer text is broken into clear, separately-announced paragraphs rather than one dense block, so screen-reader pacing matches how a sighted user would read it in discrete chunks.
- The contact-type toggle and active-share list mirror under RTL.

#### Future Enhancements
Supporting more than one simultaneous share per Table (e.g., both a Crew member and a backup external contact) is a reasonable future addition, not required for v1. A per-device saved "usual contact" quick-pick (pre-filling, not auto-sending, the external-contact field) could reduce friction without reintroducing a standing always-on share.

---

### 30. Bill Split Setup

#### Purpose
Lets a Table's host configure how the bill will be split among attendees — even-split, host-covers, or custom-amount — and send split requests accordingly.

#### Primary User
The Table's host.

#### Entry Points
- A post-Table prompt on the Live Table / Table Detail screen once a Table reaches Happened.
- Crew Detail's Table history, via a "Split bill" action on a past Table without a completed split.

#### Exit Points
- "Send Split Requests" primary button → calls `createSplitRequest` (one call per attendee, each idempotent) → navigates to Split Request / Payment Detail (Screen 31), host view, showing the newly sent requests.
- Cancel/back → discards the in-progress split configuration; no requests are sent.

#### UI Components
- A three-way mode selector — Even Split, Host Covers, Custom Amount — presented as equally sized, equally weighted options in that visual order, with no default pre-selected and no option styled as more "normal" or recommended than the others. This is a deliberate values-driven choice: bill-splitting norms vary by group and the product must not editorialize about which mode is standard.
- Total bill amount field.
- Attendee list with per-person amounts, either computed automatically (Even Split), zeroed out (Host Covers), or individually editable (Custom Amount).
- Optional tip/tax fields, factored into whichever mode is active.
- A reconciliation summary row confirming the sum of per-person amounts equals the stated total.
- Terracotta primary "Send Split Requests" button.

#### API Calls
- `createSplitRequest` (idempotent, `idempotencyKey` per request) — one call per attendee owed money (Host Covers mode still confirms the total but generates no attendee-facing requests).

#### Validation Rules
- In Custom Amount mode, the sum of individually entered amounts must equal the stated bill total before "Send Split Requests" is enabled.
- Even Split divides the total evenly only across attendees whose RSVP is Going (not Waitlisted or Requested), since those are the only confirmed diners.
- Host Covers mode requires the host to confirm the total but does not require or allow per-attendee amount entry.
- All amounts must be positive and formatted as valid currency.
- Re-sending split requests for a Table that already has requests sent requires an explicit "Resend" action rather than a silent duplicate; the `idempotencyKey` guards against accidental double-submission from a single tap.

#### Loading States
Skeleton-pulse placeholder over the attendee list while the Table roster is fetched. The "Send Split Requests" button shows a disabled, pulsing "Sending…" state during submission.

#### Empty States
If the Table has no eligible Going attendees to split with (e.g., a solo no-show Table), an inline message reads "No attendees to split with," and the send button is disabled.

#### Offline Behavior
Fully blocked offline — financial requests require guaranteed, immediate server confirmation and are never queued silently: "Connect to send split requests. This can't be done offline."

#### Analytics Events
- `split_request_created` (new) — fired once per attendee request successfully sent.
- `split_mode_selected` (new) — fired when the host picks Even Split, Host Covers, or Custom Amount, useful for understanding real-world split-mode distribution without editorializing in the UI itself.

#### Accessibility Notes
- The three mode options are implemented with identical semantic structure (same role, same description pattern) so no mode reads as "primary" or "default" to assistive technology either — matching the neutral visual treatment.
- Amount fields use a numeric keyboard.
- Layout direction mirrors under RTL; numeral formatting itself does not mirror.

#### Future Enhancements
No enhancements identified as outstanding for this screen; the neutral three-mode presentation is treated as a firm, values-driven requirement rather than a placeholder to revisit.

---

### 31. Split Request / Payment Detail

#### Purpose
The detail view of a single split request or payment — used by the paying attendee (to pay or dispute) and by the host (to track aggregate status).

#### Primary User
Both the attendee (payer) and the host, with the same screen adapting its primary action based on which role the viewer holds.

#### Entry Points
- Push notification tap on a payment request.
- Notification Center item (Screen 35).
- Crew Detail / Table history "View split" link.
- Bill Split Setup's post-send confirmation (host view, immediately after sending requests).

#### Exit Points
- "Pay Now" (payer view) → calls `confirmPayment` → success state, status chip updates.
- "Dispute this charge" → opens an inline dispute sheet → submits via `flagSplitPaymentDispute` → status moves to "Disputed — under review."
- **A failed-payment recovery path, not just a success path:** if the Stripe webhook reports `payment_intent.payment_failed` (`API_SPEC.md` §3.6), the payer sees this screen's status chip move to "Failed" with a "Try again" primary action re-opening the same payment sheet against the same `splitRequestId`/PaymentIntent, rather than being left on an unresolved "Requested" chip with no indication anything went wrong. This is the same retry-prompt notification the webhook handler already dispatches (`API_SPEC.md` §3.6); this screen is that notification's landing target.
- Back → returns to the originating screen (Notification Center, Table history, etc.).

#### UI Components
- Amount owed and Table context summary (activity, date, host or Crew name).
- A payment-specific status chip — Requested / Paid / **Failed** / Disputed / Refunded — styled consistently with the design system's chip pattern but using its own vocabulary, distinct from the RSVP chip set (Going/Requested/Waitlisted/Not Going), since payment state and attendance state are deliberately different axes and should not share labels. "Failed" was missing from this vocabulary in an earlier pass despite `confirmPayment` and the Stripe webhook (`API_SPEC.md` §3.6) both being able to return/set exactly that mirrored `splitPaymentStatus` value — a real status with no prior UI treatment, corrected here.
- Payer view: Terracotta primary "Pay Now" button (relabeled "Try again" when the current status is Failed), plus a directly reachable secondary "Dispute this charge" button/link on the same screen.
- Host view: a status summary list across all attendees' payment states for that Table, no "Pay Now" action.
- Dispute sheet: reason field, submit action.
- A timeline of status changes (Requested → Paid, Requested → Failed → Paid (retry), or Requested → Disputed → Under Review → Refunded/Resolved).

#### API Calls
- `confirmPayment` (idempotent).
- `flagSplitPaymentDispute` (idempotent) — powers "Dispute this charge." Previously this screen specified a full dispute UI against an endpoint that didn't yet exist anywhere in `docs/API_SPEC.md`; that gap is now closed (`API_SPEC.md` §3.6), and this screen's dispute sheet maps directly onto its `reasonCode` enum (`incorrect_amount` | `did_not_attend` | `suspected_fraud` | `other`).

#### Validation Rules
- "Pay Now" is disabled if the request is already Paid or currently Disputed/Under Review; it re-enables (relabeled "Try again") if the status is Failed, since a failed charge is exactly the case where retrying is the intended next step, not a dead end.
- A dispute requires a reason (structured reason code and/or required free text).
- A dispute can only be initiated within a bounded window after the charge — a reasoned default of 14 days post-Table is used here (enforced server-side as `ALREADY_PAID_NO_DISPUTE_WINDOW` per `API_SPEC.md` §3.6), flagged in Future Enhancements as needing an explicit, real policy decision rather than being treated as final.
- Only the payer can initiate a dispute on their own charge; a host cannot dispute a request they themselves sent (`permission-denied` server-side per `API_SPEC.md` §3.6).
- A charge in the Failed state can still be disputed instead of retried (e.g., the payer believes the amount itself was wrong, not just that the card declined) — Failed and Disputed are not mutually exclusive entry points into this screen's two actions.

#### Loading States
Skeleton-pulse over the amount/status block while the record is fetched; the action button shows a disabled, pulsing state during `confirmPayment` or dispute submission.

#### Empty States
Not a data-list screen. If the underlying split request has been voided or deleted, the screen shows "This split request is no longer available."

#### Offline Behavior
Both "Pay Now" and "Dispute this charge" are blocked offline, since both are financial actions requiring guaranteed live confirmation. A read-only cached view of the last known status remains visible with the banner "You're offline — showing the last status we have."

#### Analytics Events
- `payment_confirmed` (new) — fired on a successful `confirmPayment` call; not yet in the fixed analytics list despite the API existing, so it is added here per the `snake_case` convention.
- `payment_failed` (new) — fired when the status chip transitions to Failed, whether observed via the webhook-driven mirrored status or a client-side `confirmPayment` response.
- `dispute_initiated` (new) — fired on dispute submission via `flagSplitPaymentDispute`.

#### Accessibility Notes
- The payment status chip always pairs its color with a text label, matching the accessibility pattern already required of RSVP chips.
- The dispute reason field has a clear label and a visible character count if length-capped.
- Timeline and amount layout mirror under RTL.

#### Future Enhancements
The `flagSplitPaymentDispute` endpoint gap referenced in earlier drafts of this screen is now resolved (`API_SPEC.md` §3.6, `DATABASE.md` §3.8). The 14-day dispute window is an assumption pending explicit policy confirmation. This screen's status copy should reflect the platform's stated dispute policy directly — e.g., "Under review — we'll make this right within 3 business days" for a flagged charge, and copy noting that a host with a repeated pattern of disputes loses bill-split privileges, so the host-facing view of this screen should surface that consequence rather than treat disputes as purely the payer's concern.

---

### 32. Profile / Me

#### Purpose
The user's own profile view — how they present to others in Discover and Crews — including verification status, bio, interests, and a post-reveal ratings summary.

#### Primary User
Self, viewing their own profile. (Viewing someone *else's* profile is a related but distinct read-only variant reachable from Discover, Crew Detail, and elsewhere — it shares this screen's visual components but is not separately numbered in this spec.)

#### Entry Points
- Bottom navigation "Me"/profile tab.
- Back-navigation from Settings.

#### Exit Points
- "Edit Profile" → inline editing of bio/interest fields on this same screen (treated as a mode of this screen, not a separately numbered one).
- Settings gear icon → Settings (Screen 33).
- TableCrew+ upsell banner → TableCrew+ Subscription (Screen 34).
- Tap a past Table in history → that Table's detail view, in its terminal Rated state.

#### UI Components
- Avatar, name, verification badge.
- Bio and interest tags.
- Ratings summary — respecting the simultaneous-reveal model: a rating for a given Table displays as "Pending" until both directions have submitted via `submitRating` or 72 hours have elapsed, never showing a one-sided partial rating in the interim.
- Table history list (Rated Tables only — Tables still in earlier lifecycle states don't appear here).
- Crew membership summary (a compact Crew Card row).
- Settings gear icon.
- TableCrew+ status or upsell banner, depending on current subscription state.

#### API Calls
No dedicated "getProfile" Cloud Function exists in the fixed list; this is a direct Firestore read of the user's own document, consistent with the client-direct read pattern used elsewhere. `submitRating` itself is not called from this screen (that belongs to the Rating screen, Screen 17) — this screen only displays the resulting rating once revealed.

#### Validation Rules
- Bio is capped at 500 characters; up to 10 interest tags are allowed — both are reasoned defaults, flagged as assumptions since not specified elsewhere.
- Verification status is read-only here; it is managed through a separate identity-verification flow (Screen 8), not editable in place on this screen.

#### Loading States
Skeleton-pulse over the avatar, bio block, and Table history rows.

#### Empty States
If there's no Table history yet, an inline (not full-illustration) message within that section reads "No Tables yet — your history will show up here after your first one," since this is a sub-section of an otherwise populated screen rather than a standalone empty screen.

#### Offline Behavior
The profile is viewable from cache, read-only. "Edit Profile" is disabled with the banner "Connect to edit your profile" — profile data feeds Discover matching and trust signals for other people and should not be silently queued while stale.

#### Analytics Events
- `profile_viewed` (new, self-view) — low priority, useful mainly for engagement funnel completeness.

#### Accessibility Notes
- The verification badge exposes a text-equivalent label/tooltip, not an icon-only signal.
- A "Pending" rating state is explicitly announced to screen readers rather than implied by the simple absence of a rating value.
- Profile header layout mirrors under RTL.

#### Future Enhancements
The 500-character bio cap and 10-tag interest limit are flagged as assumptions that should be confirmed against actual product intent rather than treated as final.

---

### 33. Settings

#### Purpose
The central hub for account, notification, privacy/safety, and subscription controls.

#### Primary User
Self.

#### Entry Points
- Gear icon on Profile/Me.
- Deep link from a push-notification settings prompt (e.g., a permissions nudge).

#### Exit Points
- Rows navigate to: Notification Center's preference sub-section (Screen 35), TableCrew+ Subscription (Screen 34), Trusted Contact Setup (Screen 29, under Safety), Data Export / Delete Account (Screen 36, under Account/Privacy), a blocked-users list (with unblock capability), Log Out (confirmation dialog → auth flow, Screen 2), and Help/Support links.

#### UI Components
- Grouped list sections: Account, Notifications, Safety & Privacy, Subscription, Support, and a destructive-styled "Log Out" row at the bottom.
- Simple boolean preferences shown as inline toggle rows (e.g., a master "Show me in Discover" toggle).
- Each navigable row shows a label, optional live-state subtitle (e.g., current subscription tier), and a chevron.
- App version/build info footer.

#### API Calls
This screen is primarily a navigation hub with no calls of its own. Simple inline toggles (e.g., Discover visibility) write directly to the user's profile document via the client-direct write pattern used elsewhere for low-risk preference data.

#### Validation Rules
- Turning off "Show me in Discover" immediately removes the user from future `searchTables`/`getMatches` results; it does not retroactively cancel any RSVPs already in place, which still require an explicit `cancelRsvp` action if the user wants out of a specific Table.
- Log Out requires a confirmation dialog before proceeding.

#### Loading States
Rows reflecting live/remote state (e.g., current subscription tier label, count of blocked users) show a brief skeleton-pulse while fetched; static navigation rows render immediately since they carry no remote dependency.

#### Empty States
Not applicable — this is a fixed navigation list, always populated regardless of account state.

#### Offline Behavior
Navigation itself works fully offline (it's just routing to other screens, each of which handles its own offline behavior). Rows reflecting live state show their last cached value with a small "offline" indicator rather than blocking navigation. Simple, low-risk, reversible preference toggles (like Discover visibility) are allowed to be changed offline and queued for sync on reconnect — this is explicitly different from the "block entirely offline" treatment given to safety- and payment-sensitive actions elsewhere in this document (Trusted Contact Setup, Report Flow, Block Confirmation, Bill Split Setup, Payment Detail), and that distinction is deliberate: Discover visibility is easily reversible and carries no real-time safety consequence if briefly stale.

#### Analytics Events
- `settings_viewed` (new, optional).
- `discover_visibility_toggled` (new).

#### Accessibility Notes
- Grouped sections use proper heading semantics.
- Toggle rows expose their current state as accessible text, not merely a visual switch position.
- Chevron direction and row layout mirror under RTL.

#### Future Enhancements
None outstanding beyond what's already flagged in the linked sub-screens.

---

### 34. TableCrew+ Subscription

#### Purpose
Lets a user view their current subscription state and subscribe to or cancel TableCrew+, which provides priority Discover placement, no per-booking service fee, and unlimited hosted Tables.

#### Primary User
Any user, subscribed or not.

#### Entry Points
- Settings row.
- Profile/Me upsell banner.
- A paywall moment when a free user hits a hosting limit (cross-reference to Create Table, Screen 10).
- A subtle, non-intrusive Discover Feed upsell, deliberately not designed as a dark pattern per the platform's values around avoiding manufactured urgency.

#### Exit Points
- "Subscribe" → opens a payment sheet (platform in-app purchase or Stripe Checkout) → on success, returns here showing active status.
- "Cancel Subscription" → a direct, immediately reachable cancel action (no interstitial retention offers, surveys, or multi-step gauntlet before the cancel control is available) → confirmation → returns here showing a cancelled-but-active-until-date status.
- Back → Settings or the originating screen.

#### UI Components
- A plan benefit list: priority Discover placement, no per-booking service fee, unlimited hosted Tables. Copy is precise about the priority-placement mechanic — "surfaced earlier when otherwise tied," never implying a match is boosted above a genuinely better one.
- Current status card: Free / TableCrew+ Active / Cancelled (active until a stated date).
- Terracotta primary "Subscribe" for free users, or a plainly labeled, immediately reachable "Cancel Subscription" control for active subscribers — no visual de-emphasis and no multi-step gate in front of it.
- Price and billing cycle display.
- "Restore Purchase" link.

#### API Calls
No dedicated named Cloud Function for subscription management exists in the fixed API list beyond the non-client-facing `stripeWebhook`. Client-side purchase flow is assumed to route through platform billing APIs (App Store / Play Billing) or a Stripe Checkout session initiated via a Cloud Function not yet named in the fixed list. This is flagged explicitly as a real `docs/API_SPEC.md` gap — a `createCheckoutSession`-style endpoint (or the equivalent platform-billing integration contract) needs formal definition before this screen can be implemented as specified.

#### Validation Rules
- "Subscribe" is not offered to a user already active; the screen instead shows the manage/cancel state.
- Cancellation takes effect at the end of the current billing period — the user retains full benefits until then, and the status card states this plainly ("Active until Aug 14 — won't renew"), never implying immediate loss of benefits on cancellation.

#### Loading States
Skeleton-pulse over the status card while the current subscription state is fetched.

#### Empty States
Not applicable — the screen always renders either a Free or a Subscribed state; there is no zero-content case.

#### Offline Behavior
Status is shown from cache, read-only, with an offline banner. Both "Subscribe" and "Cancel Subscription" are disabled offline, since payment actions require a live connection: "Connect to manage your subscription."

#### Analytics Events
- `subscription_started` (new), `subscription_cancelled` (new).
- A future addition to `discover_search_performed` (e.g., a `plus_priority_applied` boolean param) would let priority-placement usage be measured directly, but this is not introduced into the existing fixed event now — flagged as a possible enhancement rather than assumed as already present.

#### Accessibility Notes
- Status card text is fully readable by a screen reader without depending on a badge icon alone for meaning.
- The Cancel Subscription control is never visually de-emphasized, hidden in a submenu, or placed behind additional taps relative to Subscribe — this is treated as both an accessibility requirement and an explicit ethical one (no dark patterns in cancellation), not just visual polish.
- Card layout mirrors under RTL.

#### Future Enhancements
The checkout/billing integration endpoint is a genuine `docs/API_SPEC.md` gap flagged for formal resolution. The possible `plus_priority_applied` analytics param addition is noted as a future enhancement, not implemented now.

---

### 35. Notification Center

#### Purpose
An in-app, persistent log of past notifications spanning Table updates, Crew activity, payment requests, and safety/report status updates, plus a link into granular notification preferences.

#### Primary User
Self.

#### Entry Points
- Bell icon in the top navigation, available from any primary screen.
- A push notification tap, as a fallback landing point if the specific deep-linked target screen fails to resolve (the primary behavior for a working push notification is to deep-link directly to the relevant screen; this screen is the durable log, not the primary navigation path).

#### Exit Points
- Tap a notification row → the relevant screen (a Table detail, Crew Chat, Split Request / Payment Detail, etc.).
- "Notification Preferences" link → a granular per-category preferences view (a section within Settings, not separately numbered here).
- Back → the previous screen.

#### UI Components
- Chronological notification list: category icon, bold unread-state styling, timestamp, one-line snippet.
- "Mark all read" affordance.
- Category filter chips: All / Tables / Crews / Payments / Safety.
- "Notification Preferences" link row.

#### API Calls
No dedicated named endpoint exists in the fixed API list for reading or updating notification state; this is treated as a direct Firestore read of a per-user notifications subcollection, with marking-as-read handled as a client-direct write, consistent with the pattern used for other simple per-user state elsewhere in this spec.

#### Validation Rules
Primarily a read/navigation screen with no meaningful input validation of its own. Within the linked notification-preferences sub-view, one rule is enforced as a values-driven safety requirement: a user cannot fully mute Safety-category notifications (e.g., report status updates) across every channel — at least one channel must remain active for that category, since safety-relevant updates should never go completely dark.

#### Loading States
Skeleton-pulse rows in Card Cream tone for both the initial fetch and scroll-based pagination.

#### Empty States
Illustration + Fraunces headline "Nothing yet" + Inter body "When something needs your attention — a Table update, a message, a payment — it'll show up here." No primary button is included, since there's nothing to create from an empty notification inbox.

#### Offline Behavior
The cached notification list is viewable read-only. New notifications cannot arrive while offline by definition (push delivery itself requires connectivity), so the screen shows a banner: "You're offline — you'll see new updates once you're back."

#### Analytics Events
- `notification_opened` (new) — fired when a notification row is tapped, carrying a `category` param.

#### Accessibility Notes
- Unread state is communicated through accessible labeling ("unread"), not bold font-weight alone.
- Category filter chips behave as a proper toggle group with clear selected-state announcements.
- Row layout and icon placement mirror under RTL.

#### Future Enhancements
The rule preventing full muting of Safety-category notifications is flagged as a values-driven design decision that deserves explicit confirmation from the Trust & Safety function before being treated as permanently locked-in product behavior.

---

### 36. Data Export / Delete Account

#### Purpose
Lets a user export their personal data and/or delete their account, with fully honest, bounded copy about the narrow financial-ledger retention exception required by law.

#### Primary User
Self.

#### Entry Points
- Settings > Account/Privacy section.

#### Exit Points
- "Export My Data" → triggers an asynchronous export job; the user is notified (via Notification Center and/or email) when the export is ready, with a download link.
- "Delete Account" → a multi-step confirmation flow (re-authentication, then a typed confirmation) → account deletion is initiated → the user is logged out → a confirmation screen and email follow.

#### UI Components
- "Export My Data" primary-styled button (this screen's default primary action).
- "Delete Account" clearly separate, destructive/Brick-toned secondary action — deliberately not competing with Export for primary visual weight, honoring the "one primary action per screen" convention by treating Export as the default primary and Delete as a distinctly separate destructive path rather than a second primary button.
- A plain-language explainer section stating exactly what is deleted immediately (profile, messages, RSVPs, location history) versus what is retained and why: a minimal, anonymized/tokenized financial transaction ledger, kept for the legally required approximately 7-year period, with no name or profile linkage retained beyond the tokenized record.
- A re-authentication step (password or biometric confirmation) gating the deletion flow.
- A typed-confirmation field (e.g., type "DELETE" to proceed) before final submission.
- A short cancellation-of-pending-deletion grace window notice (a reasoned addition — e.g., 14 days — since existing product facts don't specify one; flagged as an assumption below).

#### API Calls
No dedicated named endpoints (`exportUserData`, `deleteAccount`/`requestAccountDeletion`) exist in the fixed API list. This is flagged explicitly as a real gap rather than silently assumed to route through some unnamed generic path — given how sensitive and irreversible these actions are, `docs/API_SPEC.md` needs to formally define both, most likely following the same idempotent-call pattern (with `idempotencyKey`) used for other mutating endpoints in this system.

#### Validation Rules
- Re-authentication is required immediately before "Delete Account" can proceed — a long-lived, stale session alone is not sufficient authorization for this action.
- The typed confirmation string must match exactly (e.g., "DELETE") before the final submit control is enabled.
- Export requests are rate-limited to one active export job at a time, to prevent abuse of the export pipeline.
- The retention-exception copy must state plainly and specifically: "Your profile, messages, RSVPs, and location history are deleted or anonymized immediately. A minimal record of payment transactions is kept in anonymized form for about 7 years, as required by financial regulations — this record can't be linked back to your name or profile." This is treated as a content/validation rule, not merely a UI nicety — the copy must never imply unqualified, total deletion.

#### Loading States
"Export My Data" shows a disabled, pulsing "Preparing your export…" state on tap; the actual export generation runs asynchronously and does not block the screen — a status row ("Export in progress — we'll notify you when it's ready") replaces the button rather than a blocking spinner. The Delete Account flow shows a pulsing state during the re-authentication and final-submission calls.

#### Empty States
Not applicable — this is an always-available action screen, not a data-listing view.

#### Offline Behavior
Both Export and Delete are blocked outright when offline, with no partial or queued behavior: "Data export and account deletion require a stable connection. Please try again when you're back online." Both action buttons remain visible but disabled (not hidden), so the user understands why the feature is temporarily unavailable rather than assuming it's missing — this is a deliberate departure from the queue-and-sync behavior used for low-risk Settings toggles, appropriate given how sensitive and one-shot these actions are.

#### Analytics Events
- `data_export_requested` (new), `account_deletion_requested` (new), `account_deletion_completed` (new).

#### Accessibility Notes
- The typed-confirmation field has a clear accessible label stating exactly what to type.
- The retention-exception disclosure is presented as plain, always-visible paragraph text — not hidden behind a tooltip or a collapsed disclosure control — since it is a material, honesty-critical piece of information that must be discoverable by a screen reader by default.
- Layout mirrors under RTL; the literal typed confirmation token itself (e.g., "DELETE") may need explicit localization consideration, since a translated confirmation word changes what the user is expected to type.

#### Future Enhancements
The 14-day grace period before final deletion is an assumption pending an explicit product/legal decision. Localization of the typed confirmation word is flagged as a detail needing a deliberate call before ship.

---

## API Gaps Surfaced by This Spec (resolved 2026-08 architecture readiness pass)

Writing a full spec for every screen originally surfaced five real gaps in `API_SPEC.md`'s fixed endpoint list. A subsequent architecture readiness review (2026-08) formally closed all five, plus found and closed several more that the same cross-check surfaced. All are now specified in `docs/API_SPEC.md`; full detail and rationale live there (§7, "Gap-Closure Note") and in `CHANGELOG.md`. Summary:

- **Duress signal** (Screen 14) → `triggerDuressSignal` (§3.4), distinct from the non-urgent `reportUser`/`reportTable`.
- **Payment dispute** (Screen 31) → `flagSplitPaymentDispute` (§3.6), with a matching `dispute` sub-schema in `docs/DATABASE.md` §3.8.
- **Account export/deletion** (Screen 36) → `exportUserData`, `deleteAccount`, `cancelPendingDeletion` (§3.8).
- **Subscription checkout/billing** (Screen 34) → `createCheckoutSession`, `cancelSubscription`, `stripeSubscriptionWebhook` (§3.6).
- **Location sharing** (Screen 29) → `createLocationShare`/`revokeLocationShare` (§3.4) — landed as a per-Table, no-standing-default opt-in rather than a persistent saved-contact CRUD; Screen 29's spec above was rewritten to match this model (2026-08).
- **Session revocation** (Settings > Security, surfaced during the same pass, not originally a numbered-screen gap) → `revokeSessions` (§3.8).
- **Additional gaps found during the same pass, not originally flagged by any screen:** `completeIdentityVerification` (§3.7, records Persona verification outcomes — underpins the entire Tier 2/Discover trust gate and had no endpoint at all before this pass); `updateCrew` (§3.2); `endTableEarly` (§3.1).

None of these were invented under a fake name in the specs above — each was named as a gap in the relevant screen's Future Enhancements field (or, for the last three, found by direct cross-check against `API_SPEC.md`), and each now has a full endpoint definition matching `API_SPEC.md`'s standard format (auth, authorization, validation, error handling, idempotency where relevant).
