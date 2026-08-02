# DATABASE.md

**Owner:** Engineering
**Status:** Living document — schema changes require a corresponding update here in the same PR
**Related:** `ARCHITECTURE.md`, `API_SPEC.md`, `SECURITY.md`, `FIREBASE.md`

## 1. Purpose and Scope

This document is the authoritative reference for TableCrew's data model as implemented in Cloud Firestore: collection layout, document schemas, denormalization decisions, indexing strategy, the security rules philosophy, and our approach to data retention/deletion. An engineer should be able to read this document and correctly write a Cloud Function or client query against any collection without guessing field names or invariants.

## 2. Why Firestore (NoSQL document store) and Not a Relational Database

TableCrew's core workload — fetch a Table and its live RSVP state, fetch a user's Crews, list Open Tables matching a filter, append a chat message — is dominated by **read-heavy, document-shaped access patterns keyed by a small number of well-known IDs**, with real-time listener support as a hard product requirement (live RSVP counts, Crew chat). This is squarely Firestore's strength:

- **Schema flexibility during pre-PMF iteration:** we expect to add/change fields on Tables, RSVPs, and Users frequently in the first year (new RSVP states, new Table metadata, new verification fields) as the product evolves. Firestore requires no migration step to add a field — new documents simply include it, old documents are handled with defaulting logic in the client/Functions layer. A relational schema would require coordinated `ALTER TABLE` migrations for the same changes, which is a meaningfully slower iteration loop for a team still discovering the right shape of the product.
- **Native real-time listeners** are the mechanism behind live RSVP counts and Crew chat (`ARCHITECTURE.md` §5.4). A relational database has no equivalent built in; we would need to bolt on a separate real-time layer (LISTEN/NOTIFY plus a pub/sub bridge, or a third-party real-time service) to get the same behavior from Postgres, which is exactly the "free" capability we're deliberately not paying engineering time to rebuild at this stage.
- **Access pattern shape is not relational-join-heavy in the hot path.** The screens users hit most (a Table's detail view, a Crew's screen, Discover results) are satisfied by fetching one document plus one or two shallow subcollection/queries, not by multi-table joins. Where cross-entity information is needed at read time, we denormalize (Section 4) rather than join, which is the idiomatic Firestore pattern and keeps read latency flat regardless of scale.

**Where we explicitly acknowledge Firestore is the wrong tool, today, by design:**

- **Complex relational analytics** (multi-dimensional cohort analysis, funnel analysis across Tables/Ratings/Reports joined by time and geography) are not done against live Firestore at all — they're done against **BigQuery**, which Firestore and Analytics data are exported into (`FIREBASE.md` §Analytics). This is our relational-analytics answer today and is sufficient because analytics queries are inherently batch/interactive-offline, not part of any user-facing request path.
- **Venue partnership reporting** — if/when Venue partners need an interactive, joined, low-latency reporting portal (not just our internal BigQuery dashboards), that is the first concrete trigger under which we'd introduce a dedicated Postgres service fed by CDC from Firestore, exactly as described in `ARCHITECTURE.md` §6, trigger (1). We call this out here again because it's the most likely near-term reason DATABASE.md would gain a "Postgres schema" companion section — it is a planned future addition, not a gap in this document.
- We do **not** use Firestore for anything requiring multi-row ACID transactions across arbitrarily many documents (Firestore transactions are real but bounded — up to 500 documents per transaction, and contended documents degrade under high write concurrency, `ARCHITECTURE.md` §6 trigger (3)); every place we need a transaction (seat confirmation, rating aggregation) is scoped to a small, known set of documents.

## 3. Collection and Document Schemas

Firestore is organized as top-level collections plus subcollections where data is naturally owned by a parent (RSVPs under a Table, messages under a Crew). All documents include `createdAt`/`updatedAt` server `Timestamp` fields (in UTC — see `ARCHITECTURE.md` §7 on i18n) unless noted. Document IDs are Firestore auto-IDs unless otherwise specified.

### 3.1 `users/{userId}` (public profile) + `users/{userId}/private/profile` (sensitive fields)

`userId` equals the Firebase Auth UID, so no separate lookup collection is needed to go from an authenticated session to a user profile.

**Why this is split into two documents, not one:** Firestore Security Rules operate at whole-document granularity — a rule can only allow or deny reading an *entire* document, it cannot redact individual fields from a read the way a server-side API response shaper could. `SECURITY.md` requires that several fields (raw-ish phone identifier, trust/safety counters, block list, email, full verification detail) never be readable by any user other than the owner, while other fields (display name, photo, bio, verification *tier* as a trust badge, rating aggregate) must be broadly readable by any authenticated user so Discover, Table rosters, and Crew screens can render other people's profiles. A single flat document cannot satisfy both requirements simultaneously under rules alone — an earlier draft of this schema modeled everything on one document with a blanket `allow read: if isSignedIn()` rule (§6), which would have leaked `trustSignals`, `blockedUserIds`, and `email` to every authenticated reader, directly contradicting `SECURITY.md`'s "blocking is silent" guarantee (a blocked user could simply read the blocker's document and see their own uid in `blockedUserIds`) and its requirement that no-show/report counters be owner-and-Functions-only. The fix is the standard Firestore pattern `SECURITY.md` itself prescribes: split into a broadly-readable public document and an owner-plus-Functions-only private document.

```
users/{userId}                          // PUBLIC profile subset — readable by any authenticated user (§6);
                                         // actual visibility net of blocking is enforced at the query/app layer
                                         // (Discover post-filter, messaging checks — API_SPEC.md §3.4), not by this rule,
                                         // since Firestore rules can't cheaply express "unless the reader blocked me."
├─ displayName: string                 // e.g., "Priya K." — shown across the app
├─ photoUrl: string | null              // Cloud Storage download URL, post-moderation
├─ bio: string | null                   // short freeform text, max 280 chars, enforced client + rules
├─ interestTags: array<string>          // e.g., ["hiking", "board-games", "wine"]
├─ verificationTierPublic: string       // enum: "unverified" | "phone_verified" | "id_verified" — a mirror of
│                                       // private/profile.verification.verificationTier, kept in sync by the same
│                                       // trigger pattern as other Snapshot fields (§4), so the trust badge is
│                                       // readable without exposing the rest of the verification record
├─ ratingAggregate: map                 // denormalized, see §4
│   ├─ averageAsHost: number | null
│   ├─ averageAsAttendee: number | null
│   ├─ ratingCountAsHost: number
│   └─ ratingCountAsAttendee: number
├─ locale: string                       // BCP-47 locale tag, drives i18n rendering client-side
├─ deletedAt: timestamp | null          // soft-delete marker, see §7 — public so any surface referencing a
│                                       // deleted user's snapshot can detect and render the tombstoned state
├─ createdAt: timestamp
└─ updatedAt: timestamp

users/{userId}/private/profile          // PRIVATE — readable only by request.auth.uid == userId; every write
                                         // Functions-only (Admin SDK) except the fields the owner may set directly
                                         // (e.g., notificationPrefs) — see §6 for the exact rule
├─ phoneNumberHash: string              // SHA-256 hash of E.164 phone; raw number never stored in Firestore, only in Firebase Auth
├─ email: string | null                 // optional, if linked via Apple/Google
├─ homeLocation: geopoint | null        // coarse (city-level, deliberately not precise address) — used for Discover defaults
├─ residencyRegion: string              // ISO region code used for data-residency routing (ARCHITECTURE.md §7)
├─ verification: map                    // source of truth; verificationTier is mirrored to the public doc, see above
│   ├─ phoneVerified: boolean
│   ├─ idVerified: boolean              // true only after successful third-party ID-verification flow (see SECURITY.md)
│   ├─ verificationTier: string         // enum: "unverified" | "phone_verified" | "id_verified"
│   └─ verifiedAt: timestamp | null
├─ dateOfBirth: string                  // ISO 8601 date ("YYYY-MM-DD"), self-reported at Screen 4 (Date of Birth
│                                       // Entry) and persisted as part of the account-creation write
│                                       // (`completeAccountSetup`, API_SPEC.md §3.9) alongside the server-side 18+
│                                       // check that gates account creation entirely (SECURITY.md's "Age Gating and
│                                       // Minimum Age Enforcement"). Previously undocumented anywhere in this schema
│                                       // despite SCREEN_SPECIFICATIONS.md Screen 4 requiring a server-validated age
│                                       // gate — added in Milestone F2 alongside the callable that actually performs
│                                       // that validation. Lives on the private document (sensitive PII, same
│                                       // reasoning as `phoneNumberHash`/`email`), and is Functions-only-writable
│                                       // after creation (§6) — a self-reported field that also gates a safety/legal
│                                       // requirement must not be editable by the account it belongs to once set,
│                                       // the same principle already applied to `verification`/`trustSignals`. The
│                                       // Tier 2 flow (`completeIdentityVerification`, API_SPEC.md §3.7) cross-checks
│                                       // its ID-derived date of birth against this exact field, per SECURITY.md's
│                                       // age-gating section.
├─ trustSignals: map                    // denormalized safety counters, write-restricted to Functions only
│   ├─ reportCount: number
│   ├─ noShowCount: number
│   ├─ substantiatedBillingDisputeCount: number  // rolling-90-day count of disputes resolved "substantiated" against
│   │                                             // this user as host (`splitRequests` §3.8) — backs FR-T25a's "2+
│   │                                             // substantiated disputes loses bill-splitting privileges" rule
│   └─ standingStatus: string           // enum: "good" | "warned" | "restricted" | "banned"
├─ blockedUserIds: array<string>        // uids this user has blocked, Functions-only-writable (blockUser callable, API_SPEC.md §3.4)
│                                       // never readable by any other client, including the blocked party — this is what
│                                       // makes "blocking is silent" (SECURITY.md) structurally true rather than convention;
│                                       // modeled as a flat field, not a subcollection, because per-user block lists are
│                                       // small (bounded by realistic human blocking behavior, not marketplace scale)
├─ notificationPrefs: map               // owner-writable directly, see FIREBASE.md §Cloud Messaging for the full trigger/
│   │                                   //   timing/mute-policy table this map's keys are drawn from
│   ├─ categories: map<string, boolean> // per-type global toggle — the complete canonical key set (not just examples) is:
│   │                                   //   {"rsvp_updates": true, "waitlist_promotion": true, "chat_messages": true,
│   │                                   //   "crew_recurrence_nudges": true, "billing": true, "discover_matches": true} —
│   │                                   //   FEATURES.md's Notifications theme "per-type mute," never a single on/off toggle.
│   │                                   //   Deliberately absent: any "safety" key. Report-status updates, Tier-2 verification
│   │                                   //   results, and duress-signal confirmations are never represented in this map at
│   │                                   //   all — there is structurally no toggle to turn them off, which is what makes
│   │                                   //   SCREEN_SPECIFICATIONS.md Screen 35's "Safety notifications can't be fully muted"
│   │                                   //   rule true by construction rather than by a UI convention a future refactor
│   │                                   //   could accidentally violate by adding one more switch to this map.
│   └─ mutedCrewIds: array<string>      // crewIds this user has muted notifications for, independent of the category
│                                       //   toggles above — FEATURES.md's "per-Crew" granularity; a muted Crew still
│                                       //   respects category toggles for any notification that isn't Crew-scoped
├─ subscription: map                    // TableCrew+ state — server-authoritative, written only by the
│                                       //   `stripeSubscriptionWebhook` handler (Functions-only, never client-writable),
│                                       //   per PRD.md FR-D16's "Stripe subscription webhooks drive this state change
│                                       //   server-side, never a client-only flag." Previously undocumented anywhere in
│                                       //   the schema despite being a Must-have (P1) monetization feature in FEATURES.md.
│   ├─ tier: string                     // enum: "free" | "tablecrew_plus"
│   ├─ status: string                   // enum: "none" | "active" | "past_due" | "canceled" | "incomplete" — mirrors
│   │                                   //   Stripe Subscription.status, mapped 1:1 so this field never invents states
│   │                                   //   Stripe doesn't already have
│   ├─ stripeCustomerId: string | null
│   ├─ stripeSubscriptionId: string | null
│   ├─ currentPeriodEnd: timestamp | null // drives FR-D16's "effective at end of current paid billing period," never
│   │                                     //   an immediate downgrade on cancel
│   ├─ cancelAtPeriodEnd: boolean       // true once the user has self-served a cancellation (FR-D16) but is still
│   │                                   //   inside a paid period they already paid for
│   └─ updatedAt: timestamp             // last webhook-driven update, for staleness/debugging visibility
├─ fcmTokens: array<map>                // {token, platform, updatedAt} — device push tokens, pruned on failure
├─ crewMemberships: array<string>       // crewIds this user belongs to — Functions-only-writable reverse index used
│                                       // solely to fan out Crew member-snapshot refreshes on profile change (§4);
│                                       // never used for authorization (Crew membership authorization reads
│                                       // `crews/{id}.memberIds`, the source of truth, not this reverse pointer)
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

Note: raw phone numbers live only in Firebase Auth (which is purpose-built to store identity credentials securely); Firestore only ever sees a hash, consistent with data-minimization (`VALUES.md`).

**Reads that need both documents** (e.g., the owner's own settings screen) issue two reads — a `get()` on `users/{userId}` plus one on `users/{userId}/private/profile` — which is a negligible cost relative to the alternative of over-broad field exposure; this is a standard, well-understood Firestore pattern, not a novel workaround.

### 3.1a `users/{userId}/photoModeration/{uploadId}`

Added Milestone F5, closing a gap `completeAccountSetup` (§3.9 below, `API_SPEC.md` §3.9) previously left unresolved: `users/{userId}.photoUrl` above is documented as "post-moderation," but until this milestone no moderation pipeline existed anywhere in this codebase, and `completeAccountSetup`'s original spec text took a raw client-supplied `photoUrl` string on faith — the two documents disagreed about whether the field was ever actually gated. This subcollection is the fix: one document per upload attempt, written **entirely** by the Storage-triggered moderation Cloud Function (`FIREBASE.md` §2.5, ADR 0006) via the Admin SDK. The client never writes this document directly — it uploads the raw photo to Cloud Storage and listens here for the verdict.

**Path corrected in Milestone F5's task #97 (rules-emulator tests):** this section originally specified `users/{userId}/private/photoModeration/{uploadId}` — 5 path segments, which is structurally invalid as a Firestore *document* path (documents always sit at an even segment count; an odd count is a collection path), so both the moderation Function's Admin-SDK write and the client's listen would have thrown on first real use. Caught while writing this path's rules tests — the first work to exercise the path against a real emulator rather than a hand-written fake. The document is now a direct subcollection of the user document. Nothing is lost by leaving the `private/` prefix behind: that prefix never carried any access-control semantics of its own (`§6`'s rules are what make `private/profile` private, and the same owner-only-read/no-client-write rules apply here), it existed to solve the public/private *field split* of the profile document specifically.

```
users/{userId}/photoModeration/{uploadId}   // PRIVATE — readable only by request.auth.uid == userId;
                                              // every field Functions-only-writable, no exceptions (§6)
├─ status: string                       // enum: "pending" | "approved" | "flagged"
├─ approvedUrl: string | null           // set only when status == "approved" — the public Cloud Storage download
│                                       // URL of the *copied*, post-moderation object (see FIREBASE.md §2.5's
│                                       // pending/ vs. approved/ path convention). completeAccountSetup reads this
│                                       // field server-side (Admin SDK) and copies it into users/{userId}.photoUrl
│                                       // — it is never taken as a raw string from the client's request body, per
│                                       // FIREBASE.md §2.5's "never written directly by the uploading client" rule.
├─ flagReason: string | null            // set only when status == "flagged" — the SafeSearch category+likelihood
│                                       // that triggered quarantine (e.g. "adult:VERY_LIKELY"), referenced by the
│                                       // Trust & Safety review task this same trigger creates (§3.6's Reports model)
├─ storagePath: string                  // the original uploaded object's path under users/{userId}/profile/pending/,
│                                       // kept for the review task even after quarantine
└─ createdAt: timestamp
```

`uploadId` is a client-generated identifier (e.g. a UUID), used as both the Storage object name under `users/{userId}/profile/pending/{uploadId}` and this document's ID — the moderation trigger derives `userId`/`uploadId` directly from the finalized object's path rather than needing a separate lookup. `completeAccountSetup`'s request contract takes `photoUploadId` (not `photoUrl`) for exactly this reason — see `API_SPEC.md` §3.9's corrected text.

### 3.2 `tables/{tableId}`

```
tables/{tableId}
├─ hostId: string                       // uid of the host, references users/{hostId}
├─ hostDisplayNameSnapshot: string      // DENORMALIZED — see §4
├─ hostPhotoUrlSnapshot: string | null  // DENORMALIZED — see §4
├─ hostVerificationTierSnapshot: string // DENORMALIZED — shown as a trust badge without extra reads
├─ title: string                        // e.g., "Sunday morning hike + brunch"
├─ interestTag: string | null           // single primary tag, drives Discover facet filtering
├─ description: string | null
├─ costBand: string | null              // enum: "$" | "$$" | "$$$" — FR-T3 optional field, also shown on every
│                                       // Discover card per FR-D2, so it's a first-class filterable/sortable field
│                                       // (synced to Typesense, `ARCHITECTURE.md` §5.5) rather than folded into `description`
├─ coverPhotoUrl: string | null         // Cloud Storage download URL, post-moderation (FIREBASE.md moderation hooks) — FR-T3
├─ accessibilityNotes: string | null    // freeform, host-entered dietary/accessibility notes (e.g., "step-free entry,
│                                       // vegetarian-friendly menu") — FR-T3; deliberately a distinct field from
│                                       // `description` so Discover/Table-detail UI can render it under its own
│                                       // labeled heading rather than requiring users to parse free text for it
├─ visibility: string                   // enum: "open" | "closed"
├─ status: string                       // enum: "proposed" | "filling" | "confirmed" | "happened" | "rated" | "cancelled"
├─ location: map
│   ├─ geopoint: geopoint | null        // null while location is TBD (below); used for Discover radius queries and Typesense sync
│   ├─ venueId: string | null           // references venues/{venueId} if a partner venue
│   ├─ venueNameSnapshot: string | null // DENORMALIZED — see §4
│   ├─ address: string | null           // human-readable, locale-appropriate formatting; null while TBD
│   ├─ isTBD: boolean                   // true if the host chose "TBD, will confirm 24h before" at creation (FR-T2)
│   └─ tbdConfirmBy: timestamp | null   // set only when isTBD is true — the 24h-before-start deadline a scheduled
│                                       // function checks to prompt the host / auto-flag the Table if location is
│                                       // still unset as the deadline approaches (FEATURES.md "Location TBD" row)
├─ startTime: timestamp
├─ capacity: map
│   ├─ min: number                      // host-set per Table, hard floor 2 — see PRODUCT.md's activity-based recommendation table for smart defaults (no single fixed default)
│   ├─ max: number                      // host-set per Table, hard ceiling 8 (corrected 2026-08 from an earlier 12 — see PRODUCT.md/FEATURES.md for why 8 is the platform-wide cap) — see PRODUCT.md for activity-based recommended defaults
│   ├─ confirmedCount: number           // DENORMALIZED, maintained transactionally — see §4
│   └─ waitlistCount: number            // DENORMALIZED
├─ crewId: string | null                // set if this Table was created by/for a Crew
├─ priceSplitEnabled: boolean           // whether Stripe split-billing is active for this Table
├─ reportFlags: map                     // write-restricted to Functions only
│   ├─ openReportCount: number
│   └─ isSuppressed: boolean            // true hides Table from Discover pending Trust & Safety review
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

Subcollection: `tables/{tableId}/rsvps/{userId}` — see §3.3 (document ID is the RSVP-ing user's uid, which makes "does user X have an RSVP on this Table" a direct document read rather than a query, and is also what security rules key off of, §6).

### 3.3 `tables/{tableId}/rsvps/{userId}`

```
tables/{tableId}/rsvps/{userId}
├─ userId: string                       // redundant with doc ID, kept for query convenience (collectionGroup queries)
├─ userDisplayNameSnapshot: string      // DENORMALIZED
├─ userPhotoUrlSnapshot: string | null  // DENORMALIZED
├─ status: string                       // enum: "invited" | "requested" | "confirmed" | "declined" | "waitlisted" | "attended" | "no_show"
├─ statusHistory: array<map>            // [{status, at: timestamp}] — audit trail of transitions
├─ respondedAt: timestamp | null
├─ splitPaymentStatus: string | null    // enum: "not_applicable" | "pending" | "paid" | "failed" | "disputed" —
│                                       // mirrors Stripe state plus the "disputed" value added for FR-T25a's
│                                       // payment-dispute flow (see `splitRequests`, §3.8); "disputed" pauses reminder
│                                       // scheduling per FR-T25a and is set by the `flagSplitPaymentDispute` callable
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

Subcollections: `tables/{tableId}/duressSignals/{userId}` and `tables/{tableId}/locationShares/{shareId}` — see §3.3a below.

### 3.3a `tables/{tableId}/duressSignals/{userId}` and `tables/{tableId}/locationShares/{shareId}`

`SECURITY.md`'s In-Table Emergency and Duress Response section references both of these subcollections directly (`tables/{tableId}/duressSignals/{userId}` for the duress signal, and the "share my location with a trusted contact" mechanism) but neither was ever given a schema entry here — a gap this section closes, backing PRD.md FR-D12 and FR-D14.

```
tables/{tableId}/duressSignals/{userId}         // Functions-only readable/writable — structurally unreadable by any
                                                 // client, mirroring the `reports` collection's unreadability (§6)
├─ triggeredAt: timestamp
├─ lastKnownLocation: geopoint | null            // only present if the triggering user had granted location permission
├─ status: string                                // enum: "open" | "acknowledged" | "resolved"
├─ linkedReportId: string | null                 // set once the paired `reports/{reportId}` document (severity
│                                                 //   "sev1", isDuressSignal: true, §3.6) is created by the same callable
└─ acknowledgedBy: string | null                 // Trust & Safety staff identifier once paged and acknowledged

tables/{tableId}/locationShares/{shareId}        // backs PRD.md FR-D14's opt-in "share my location with a trusted
                                                 // contact for this Table" — Functions-only writable; read access is
                                                 // via a signed, time-limited, unauthenticated-viewable link (SECURITY.md),
                                                 // not a normal Firestore client read, since the trusted contact may not
                                                 // have a TableCrew account at all
├─ sharingUserId: string                         // the attendee who opted in
├─ contactType: string                           // enum: "crew_member" | "external_sms"
├─ contactUserId: string | null                  // set if contactType == "crew_member"
├─ contactPhoneHash: string | null               // set if contactType == "external_sms" — SHA-256 hash, raw number
│                                                 //   lives only in the SMS-delivery Cloud Function's transient invocation,
│                                                 //   consistent with §3.1's phoneNumberHash minimization pattern
├─ signedLinkToken: string                       // opaque token embedded in the shared link; the sole credential
│                                                 //   gating read access to this document's live-location view
├─ liveLocation: geopoint | null                 // updated periodically while the share is active
├─ revokedAt: timestamp | null                   // set immediately if the sharing user revokes early (SECURITY.md: "revocable at any time with immediate effect")
├─ expiresAt: timestamp                          // Table's `happened` transition or a fixed 6-hour ceiling, whichever
│                                                 //   first (Firestore TTL policy field, same mechanism as §3.9)
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

We use a `collectionGroup` index on `rsvps` (Section 5) to answer "all RSVPs for user X across every Table" without needing a separate top-level `rsvps` collection or a denormalized array-of-Table-IDs on the User document.

### 3.4 `crews/{crewId}`

```
crews/{crewId}
├─ name: string
├─ photoUrl: string | null
├─ creatorId: string                    // uid of the creator/original admin
├─ memberIds: array<string>             // uids — used for simple "is member" security-rule checks
├─ members: map<string, map>            // keyed by uid, DENORMALIZED per-member snapshot — see §4
│   └─ {uid}: { displayNameSnapshot, photoUrlSnapshot, role: "admin"|"member", joinedAt }
├─ tableHistoryCount: number            // DENORMALIZED count of past Tables, avoids a count() query
├─ recurrence: map | null               // e.g., { cadence: "biweekly", dayOfWeek: "saturday", nextSuggestedAt }
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

Subcollection: `crews/{crewId}/messages/{messageId}` (chat, §ARCHITECTURE.md §5.4):

```
crews/{crewId}/messages/{messageId}
├─ senderId: string
├─ senderDisplayNameSnapshot: string    // DENORMALIZED
├─ text: string                         // max length enforced client + rules
├─ tableRef: string | null              // optional reference tableId if the message is a system/Table-linked message
├─ type: string                         // enum: "user" | "system"  (system = e.g., "Table confirmed" auto-message)
└─ createdAt: timestamp
```

**Blocking within a shared Crew:** a block between two Crew members does not remove either party from `memberIds`/`members` (Crew membership is unaffected — leaving is a separate, deliberate `leaveCrew` action), but per `SECURITY.md`'s "Reporting and Blocking" section, messages between the two blocking parties are mutually hidden going forward. This is enforced the same way Discover's block-filtering is (§3.1's comment on `users/{userId}`'s public doc) — an **app-layer post-filter** on the client's rendered message list against the viewer's own `private/profile.blockedUserIds`, not a Firestore rule, since a rule evaluated per-message would need to read the *reader's* private block list against every message's `senderId` on every listener update, which is both expensive and not how Firestore rules read another document's data cheaply at this granularity. The underlying message documents are unaffected for every other Crew member — only the two blocking parties' own rendered views differ.

Subcollection: `crews/{crewId}/tableHistory/{tableId}` — a lightweight pointer collection (`{tableId, occurredAt, attendeeCount}`) maintained by a trigger whenever a Crew-linked Table reaches `happened`, so "this Crew's past Tables" is a cheap ordered query rather than a filtered scan of the top-level `tables` collection.

### 3.5 `ratings/{ratingId}`

Ratings are bidirectional (host rates attendees, attendees rate host and each other optionally), so each rating is its own document rather than a field on the Table, to support many-to-many rating pairs per Table.

```
ratings/{ratingId}
├─ tableId: string                      // references tables/{tableId}
├─ raterId: string                      // uid of who submitted the rating
├─ ratedUserId: string                  // uid of who is being rated
├─ pairKey: string                      // deterministic `{tableId}_{min(raterId,ratedUserId)}_{max(raterId,ratedUserId)}`
│                                       // — lets a trigger cheaply find "the other direction of this specific pairing"
│                                       // without a query, which is what FR-T29a's simultaneous-reveal condition needs
│                                       // to check on every new rating write
├─ direction: string                    // enum: "host_to_attendee" | "attendee_to_host" | "attendee_to_attendee"
├─ score: number                        // 1-5
├─ tags: array<string>                  // e.g., ["great_conversation", "on_time"], optional structured feedback
├─ comment: string | null               // optional freeform, moderated
├─ visibility: string                   // enum: "private_to_platform" | "shown_on_profile" — most ratings feed aggregates only
├─ revealState: string                  // enum: "pending" | "revealed" — PRD.md FR-T29a: a rating is not shown to the
│                                       // rated party, and does not contribute to any visible aggregate, until either
│                                       // both directions of `pairKey` exist or 72 hours have elapsed since the Table's
│                                       // rating window opened, whichever first. Previously undocumented: the schema
│                                       // had no field distinguishing "submitted" from "revealed," so nothing actually
│                                       // enforced simultaneous reveal at the data layer.
├─ revealedAt: timestamp | null         // set by the trigger described below when revealState flips to "revealed"
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

A Firestore trigger on `ratings` creation (a) looks up `pairKey` for a counterpart document; if one exists, both documents' `revealState` flip to `"revealed"` (and `revealedAt` is set) in the same transaction, and the `ratedUserId → ratingAggregate` recompute (§3.1) runs for both; if no counterpart exists yet, this document stays `"pending"` and a scheduled function sweeps any rating still `"pending"` 72 hours after its Table's rating window opened, flipping it to `"revealed"` unilaterally per FR-T29a's timeout clause. We recompute the aggregate rather than incrementally update it in the common case, because rating aggregates are low-write-volume (bounded by Table frequency per user) and recomputation avoids drift; see `API_SPEC.md` §Ratings for exact trigger behavior. Critically, `ratingAggregate` (§3.1) must only ever be recomputed from ratings where `revealState == "revealed"` — including a `"pending"` rating in the aggregate would leak its existence/value to the rated party indirectly via their own aggregate shifting, defeating the point of simultaneous reveal.

### 3.6 `reports/{reportId}`

Reports are deliberately **not** a subcollection of `users` or `tables` — they must never be readable by the user/Table being reported, and keeping them top-level with restrictive rules (§6) makes that boundary structurally obvious rather than dependent on remembering to exclude a nested path.

```
reports/{reportId}
├─ reporterId: string
├─ targetType: string                   // enum: "user" | "table"
├─ targetId: string                     // uid or tableId depending on targetType
├─ reasonCode: string                   // enum: "safety_concern" | "no_show" | "harassment" | "fake_profile" |
│                                       //   "off_platform_stalking" | "flagged_media" | "other" — `off_platform_stalking`
│                                       //   is its own value (not folded into "harassment") so it's separately
│                                       //   queryable/trackable, per SECURITY.md's "Off-platform contact and stalking
│                                       //   after a Table" section. `flagged_media` (added Milestone F5) is the only
│                                       //   reasonCode a human never files directly — it's written by the photo-
│                                       //   moderation Cloud Function itself (FIREBASE.md §2.5, ADR 0006) on a flagged
│                                       //   SafeSearch verdict, with `reporterId: "system:photo-moderation"` rather
│                                       //   than a real uid, since there's no human reporter for an automated flag
├─ severity: string                     // enum: "sev1" | "sev2" | "sev3" | null — set at intake (null until triaged
│                                       //   for reasonCodes without a fixed severity) or fixed at creation for
│                                       //   reasonCodes with a definitionally-fixed severity (a duress signal is
│                                       //   always "sev1", `off_platform_stalking` is always at least "sev2" — see
│                                       //   SECURITY.md's Incident Response and Off-platform-stalking sections). This
│                                       //   field is what the Trust & Safety surge-protocol trigger in SECURITY.md
│                                       //   ("SEV1/SEV2 incident rate exceeds a defined multiple of trailing 7-day
│                                       //   average, tracked via the same reports composite index") actually queries —
│                                       //   previously that trigger had no backing field to query against.
├─ isDuressSignal: boolean              // true if this report originated from the live-Table duress affordance
│                                       //   (`tables/{tableId}/duressSignals/{userId}`, see §3.2a) rather than a
│                                       //   standard report flow — lets Trust & Safety tooling distinguish the two
│                                       //   without guessing from reasonCode alone
├─ details: string | null
├─ status: string                       // enum: "open" | "under_review" | "resolved_no_action" | "resolved_action_taken"
├─ assignedTo: string | null            // Trust & Safety staff identifier
├─ resolutionNotes: string | null       // internal-only, never client-readable regardless of role
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

A second composite index — (`severity` ASC, `status` ASC, `createdAt` ASC) — supports the SEV1/SEV2 surge-detection query referenced above; added to §5 alongside the existing `reports` indexes.

### 3.7 `venues/{venueId}`

```
venues/{venueId}
├─ name: string
├─ partnerStatus: string                // enum: "none" | "pending" | "active" | "paused"
├─ location: map
│   ├─ geopoint: geopoint
│   └─ address: string
├─ contactEmail: string | null          // partner contact, not shown to end users
├─ capacityHints: map | null            // e.g., { typicalMaxPartySize: 10 }
├─ photoUrls: array<string>
├─ tableCountLifetime: number           // DENORMALIZED, incremented by trigger when a Table at this venue reaches "happened"
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

### 3.8 `splitRequests/{splitRequestId}`

This collection was previously undocumented here despite being referenced throughout `API_SPEC.md` (`createSplitRequest` returns a `splitRequestId`; `confirmPayment` looks one up by it; the `stripeWebhook` handler resolves incoming events against it) — it is the actual financial transaction ledger for split-bill payments and is the collection the retention exception in §7 applies to, so it needs a first-class schema entry like every other collection in this document.

```
splitRequests/{splitRequestId}
├─ tableId: string                     // references tables/{tableId}
├─ hostId: string                      // uid of the host who initiated the split (or an anonymized token post-deletion, §7)
├─ totalAmountCents: number
├─ currency: string                    // ISO 4217, e.g., "usd"
├─ splitMethod: string                 // enum: "even" | "custom"
├─ perAttendeeStatus: map<string, map> // keyed by uid (or anonymized token post-deletion, §7)
│   └─ {uid}: { amountCents: number, stripePaymentIntentId: string, status: string, /* mirrors RSVP splitPaymentStatus, including "disputed" */
│               dispute: map | null }  // present only while status == "disputed" — see below
├─ idempotencyKey: string              // client-supplied key for createSplitRequest, see §3.9 — prevents duplicate
│                                       // PaymentIntent creation if the client retries after a dropped response
├─ createdAt: timestamp
└─ updatedAt: timestamp
```

**Payment dispute sub-structure** (`perAttendeeStatus.{uid}.dispute`), backing PRD.md FR-T25a — previously the "disputed" case had no schema anywhere despite being a named Phase 0 launch-blocker (`PRD.md` §8):

```
perAttendeeStatus.{uid}.dispute
├─ reasonCode: string                  // enum: "incorrect_amount" | "did_not_attend" | "suspected_fraud" | "other"
├─ details: string | null
├─ flaggedAt: timestamp                // pauses further reminders on this request immediately, per FR-T25a
├─ reviewDueBy: timestamp              // flaggedAt + 3 business days — the stated review SLA
├─ resolution: string | null           // enum: "substantiated" | "unsubstantiated" | null (still open)
├─ resolvedAt: timestamp | null
├─ refundIssued: boolean               // true if resolved by making the attendee whole (FR-T25a's "made whole by
│                                       // default if unresolved within the window" policy, or a substantiated dispute)
└─ resolvedBy: string | null           // Trust & Safety staff identifier
```

A substantiated dispute (`resolution == "substantiated"`) increments `substantiatedBillingDisputeCount` on the **host's** `trustSignals` (§3.1) via the same Functions-only trigger pattern as `noShowCount` — this is the field the "2+ substantiated billing disputes in a rolling 90-day window loses bill-splitting privileges" rule (FR-T25a) actually checks; the schema had no counter for this rule to reference before this pass.

Firestore holds this as a **mirror** of Stripe state (`ARCHITECTURE.md` §8) — Stripe's PaymentIntent objects remain the authoritative record of what was actually charged; this document exists so the app doesn't need a live Stripe API call on every read, and so we have a queryable, retained financial audit trail scoped to our own retention/anonymization policy (§7) independent of how long Stripe itself retains the underlying objects.

### 3.9 `idempotencyKeys/{idempotencyKey}`

Backing store for the idempotency-key requirement on capacity- and payment-mutating callables (`API_SPEC.md` §2, §3.1, §3.6) — a mobile client on a flaky connection that retries `requestSeat`, `confirmAttendee`, `createSplitRequest`, or `confirmPayment` must not double-book a seat or double-charge a card.

```
idempotencyKeys/{idempotencyKey}       // idempotencyKey is client-generated (UUID v4), namespaced by the client
                                        // per logical action so retries of the *same* user action reuse the same key
├─ uid: string                         // caller, so a key can't be replayed cross-account
├─ endpoint: string                    // e.g., "requestSeat", "createSplitRequest"
├─ status: string                      // enum: "in_progress" | "completed"
├─ response: map | null                // the exact response payload returned the first time, replayed verbatim on
│                                       // a duplicate call while status == "completed", so retries are provably safe
├─ createdAt: timestamp
└─ expiresAt: timestamp                // TTL policy field (Firestore TTL feature) — keys expire after a bounded
                                        // window (e.g., 24h), long enough to cover realistic client retry/backoff
                                        // windows but short enough that this collection doesn't grow unbounded
```

**Mechanics:** at the top of any idempotency-key-bearing callable, the function attempts to `create()` (not `set()`) a document at `idempotencyKeys/{idempotencyKey}` with `status: "in_progress"`. If the create fails because the document already exists, the function reads its `status`: `"completed"` means it returns the stored `response` verbatim without re-executing any business logic (no second seat decrement, no second PaymentIntent); `"in_progress"` (a genuine concurrent duplicate, not a retry-after-response) means it returns a `failed-precondition` (`DUPLICATE_REQUEST_IN_FLIGHT`) rather than racing the original. On successful completion, the function updates the document to `status: "completed"` with the response payload; on failure, it deletes the claim entirely rather than leaving it `"in_progress"` forever, since a genuinely failed attempt is always safe to retry with the same key.

**Correction (2026-08, Milestone F4):** the paragraph above previously said the `"in_progress"` create and the business-logic write happen "inside the same transaction," and that the completion update happens "atomically with the business-logic write it's guarding." Neither is true of the actual implementation (`functions/src/shared/idempotency.ts`): the idempotency-key claim/completion writes are their own separate operations, not merged into whatever transaction the wrapped business logic itself runs (which varies per endpoint — e.g. `requestSeat`'s own capacity-invariant transaction, §5's indexing note). This means there is a narrow window — a crash between the business logic committing and the completion-update running — where a key could be stuck `"in_progress"` despite the underlying action having actually succeeded; a client retrying in that exact window gets `DUPLICATE_REQUEST_IN_FLIGHT` until `expiresAt`'s TTL clears it, rather than an immediate replayed success. This is an availability tradeoff (a rare, bounded delay), not a safety one — no double-booking or double-charge can result, since the business logic's own transaction is what actually enforces those invariants, independent of this store. Merging two independently-shaped transactions (a generic idempotency wrapper's, and each endpoint's own business-specific one) generically was judged not worth the added complexity for this bounded, TTL-recovered edge case; revisit if real-world crash timing ever makes this a practical problem rather than a theoretical one.

### 3.9a `rateLimits/{bucketId}`

Backing store for the per-user, per-endpoint-family rate limits `API_SPEC.md`'s per-endpoint "Abuse prevention" notes describe (e.g. `createTable`'s "10 Table creations per user per rolling 24h," the shared "60 calls/hour" Table-/Crew-mutation families). Explicitly deferred from Milestone F2 to F4 as a shared mechanism (`TASKS.md`'s F2 entry) rather than built bespoke per callable.

```
rateLimits/{bucketId}                  // bucketId = `${uid}_${family}_${windowStartMs}` — deterministic, so the
                                        // same caller within the same window always addresses the same document,
                                        // which is what makes a plain transactional read-check-increment correct
├─ uid: string
├─ family: string                      // e.g., "createTable", "tableMutation", "crewMutation" — see
│                                       //   functions/src/shared/rateLimit.ts for the exact family names in use
├─ windowStart: timestamp               // the fixed window's start instant
├─ count: number                       // calls made by this uid, in this family, within this window
└─ expiresAt: timestamp                // TTL policy field (same mechanism as §3.9), set to windowStart + window
                                        // length + a small grace buffer, so old buckets don't accumulate forever
```

**Mechanics:** fixed-window, not sliding-window or token-bucket — `createTable`'s own spec text already described a "counter keyed by uid+day," and a fixed window is the simplest mechanism that satisfies every limit this milestone's scope actually needs (day-granularity for `createTable`, hour-granularity for everything else) without a more complex sliding-window structure nothing here calls for. The well-known fixed-window edge case (a burst straddling a window boundary can momentarily allow up to roughly 2x the stated limit) is an accepted tradeoff at this traffic scale, not an oversight — revisit if real abuse patterns ever exploit it specifically. Each check is its own small atomic Firestore transaction (read the bucket, compare `count` against the limit, increment or reject) — see `API_SPEC.md`'s `createTable` abuse-prevention note for why this doesn't need to be merged into whatever transaction the endpoint's own business logic runs.

## 4. Denormalization Decisions and Rationale

Firestore has no server-side joins, so every screen that would need one in a relational model requires a deliberate choice: denormalize (copy a snapshot of the data you need onto the document you're reading) or fan out multiple reads client-side. We denormalize aggressively for data that is (a) read far more often than it changes, and (b) tolerable to display slightly stale for a short window. Specific decisions:

- **`tables/{id}.hostDisplayNameSnapshot` / `hostPhotoUrlSnapshot` / `hostVerificationTierSnapshot`:** every Discover list render and every Table detail view needs the host's name, photo, and trust badge. Without denormalization, rendering a list of 20 Discover Tables would require 20 additional `users/{hostId}` reads (or a batched `getAll`, which is still 20x the read cost and adds latency). We copy these fields onto the Table at creation time and refresh them via two chained Firestore triggers: (1) a trigger on `users/{hostId}/private/profile` writes recomputes `users/{hostId}.verificationTierPublic` whenever `verification.verificationTier` changes (§3.1's public/private split), and (2) a trigger on `users/{hostId}` (the public document) writes — covering `displayName`, `photoUrl`, or the just-mirrored `verificationTierPublic` — patches all of that host's non-terminal-status Tables. Staleness window is bounded by trigger propagation (typically sub-second, now two hops instead of one because of the public/private split, but still well under a second in practice) and is acceptable because a host's name/photo/trust-tier changes are rare events, not something users expect to see update mid-session.
- **`tables/{id}.rsvps/{userId}.userDisplayNameSnapshot` / `userPhotoUrlSnapshot`:** identical reasoning — rendering "who's coming" on a Table detail screen from N RSVP subcollection documents must not require N additional User reads.
- **`crews/{id}.members` map with per-member snapshots:** rendering a Crew roster or chat sender name/photo must not require a read per member; refreshed the same way (trigger on `users/{uid}` — the public document — write patches any Crew the user belongs to, looked up via a `collectionGroup`-free reverse index we maintain: `users/{uid}/private/profile.crewMemberships: array<string>` of crewIds for this fan-out purpose, Functions-only-writable).
- **`tables/{id}.location.venueNameSnapshot`:** avoids a `venues/{id}` read on every Table render just to show the venue's name; refreshed via trigger on `venues/{id}.name` change (rare). For non-partner venues (no `venues/{id}` document exists — provider-matched or manually-entered via Screen 11), the snapshot is populated directly from `createTable`/`updateTable`'s request-side `location.venueName` field (added Milestone F6, `API_SPEC.md` §3.1) and there is nothing to refresh from.
- **`tables/{id}.capacity.confirmedCount` / `waitlistCount`:** the single most important denormalized field in the schema — it is what makes "how many people are going" an O(1) document read instead of an aggregation query over the RSVP subcollection on every render. This field is **not** eventually-consistent via trigger alone; it is maintained **transactionally** inside the `requestSeat`/`confirmAttendee`/`cancelTable` callable functions (`API_SPEC.md`) precisely because it gates a business invariant (never exceed `capacity.max`), and a trigger-only approach (react after the RSVP write) would allow two racing requests to both see "1 seat left" and both write RSVPs. A Firestore-triggered function still exists as a reconciliation safety net (recomputes the count from the RSVP subcollection on a schedule and on RSVP document writes, correcting any drift), but the authoritative real-time write path is the transaction.
- **`crews/{id}.tableHistoryCount`, `users/{id}.ratingAggregate`, `venues/{id}.tableCountLifetime`:** all are counts/aggregates that are expensive to compute live (would require scanning a subcollection or collection-group query every render) and are updated incrementally by triggers on the relevant child writes (new Table reaching `happened`, new Rating created).

**General rule we enforce in code review:** any field with a `Snapshot` suffix or that is clearly an aggregate (`Count`, `Aggregate`) is documented in this file with (1) what it's derived from and (2) which trigger keeps it in sync — a denormalized field with no documented sync mechanism is treated as a bug.

## 5. Indexing Strategy

Firestore automatically indexes every field for single-field equality/range queries; **composite indexes** must be explicitly declared (in `firestore.indexes.json`, deployed via CI/CD per `CI_CD.md`) for any query combining multiple fields with range/inequality or multiple `orderBy`s. The composite indexes this schema requires:

- **Discover fallback/secondary queries** (primary Discover search runs through Typesense, `ARCHITECTURE.md` §5.5, but we still need Firestore-side composite indexes for: admin tooling, the backfill/reconciliation function that repopulates Typesense, and any Firestore-native fallback query): `tables` collection, composite on (`visibility` ASC, `status` ASC, `startTime` ASC) — supports "all open, filling-or-confirmed Tables starting soon" scans.
- **Table listing by host:** `tables` collection, composite on (`hostId` ASC, `status` ASC, `startTime` DESC) — supports a user's "my hosted Tables" screen filtered by status.
- **RSVP collection-group query by user:** collection-group index on `rsvps` for (`userId` ASC, `status` ASC, `createdAt` DESC) — supports "all my upcoming confirmed RSVPs across every Table" without a top-level rsvps collection.
- **Crew Tables by recency:** `tables` collection, composite on (`crewId` ASC, `startTime` DESC) — supports a Crew's "upcoming Tables" list.
- **Reports queue for Trust & Safety tooling:** `reports` collection, composite on (`status` ASC, `createdAt` ASC) — supports the internal triage queue (oldest open reports first); a second composite on (`targetType` ASC, `targetId` ASC, `status` ASC) supports "all open reports against this specific user/Table"; a third composite on (`severity` ASC, `status` ASC, `createdAt` ASC) supports the SEV1/SEV2 surge-detection query described in `SECURITY.md`'s Incident Response surge protocol (§3.6). **Added Milestone F6:** a fourth composite on (`reporterId` ASC, `targetType` ASC, `targetId` ASC, `status` ASC) backs `reportUser`/`reportTable`'s own `already-exists` duplicate check (`API_SPEC.md` §3.4 — "an identical open report from the same reporter against the same target already exists"), which the second composite above can't serve since it has no `reporterId` field at all.
- **Venue partner Table history:** `tables` collection, composite on (`location.venueId` ASC, `status` ASC, `startTime` DESC) — supports venue-scoped reporting views before/if those graduate to the Postgres reporting service (`ARCHITECTURE.md` §6).
- **Split-request lookup by Table:** `splitRequests` collection, single-field index on `tableId` (Firestore's automatic single-field indexing covers this) — supports "does this Table already have an active split request" checks in `createSplitRequest`; a composite on (`hostId` ASC, `createdAt` DESC) supports a host's payment-history view and the scheduled anonymization sweep's per-user lookup (§7).

We deliberately keep the number of composite indexes small: each composite index has a storage and write-cost overhead (every index is updated on every relevant write), and over-indexing is a real Firestore cost driver (`FIREBASE.md` §cost management) — we add a composite index only when a specific product query needs it, not speculatively.

## 6. Security Rules Philosophy

Full rules implementation and threat-model detail live in `SECURITY.md`; this section sketches the structure so schema and rules are read together. Our guiding principle (per `VALUES.md` — safety is architecture, not policy): **default-deny, then explicitly allow the minimum each collection needs**, with authorization logic that mirrors the invariants described in Section 4 (e.g., anything that must be transactionally consistent, like capacity counts, is rules-*read-only* for clients and Functions-only for writes).

Structural sketch (illustrative, not the literal deployed rules file):

```
match /databases/{database}/documents {

  match /users/{userId} {
    // PUBLIC document (§3.1) — safe for any authenticated user to read in full, because this document
    // by construction contains nothing SECURITY.md restricts (no phone hash, no trust/report counters,
    // no block list, no email, no verification detail beyond the public tier badge).
    allow read: if isSignedIn();
    allow update: if isSignedIn() && request.auth.uid == userId
                  && !request.resource.data.diff(resource.data)
                       .affectedKeys().hasAny(['ratingAggregate', 'verificationTierPublic', 'deletedAt']);
      // a user may edit their own public display fields, but never their own rating aggregate, verification
      // tier badge, or deletion marker — those are Functions-only, written by triggers/callables using the
      // Admin SDK (which bypasses rules).
    allow create: if false;
      // Corrected in Milestone F2: this document previously (Milestone F1) allowed a direct client
      // create by the document's own owner (`if isSignedIn() && request.auth.uid == userId`), on the
      // reasoning that a user can only ever create *their own* uid's document, never someone else's.
      // That reasoning is true but incomplete — Firestore rules cannot restrict which *field values* a
      // create() call sets, so a modified client could have created its own profile with, e.g.,
      // `verificationTierPublic: "id_verified"` before ever completing Tier 2, a real self-elevation
      // bypass. Now that a real account-creation callable exists (`completeAccountSetup`, API_SPEC.md
      // §3.9), creation is Functions-only, matching how `crews` already works (§3.4) — the callable
      // validates the DOB/age gate and sets every default field itself via the Admin SDK, which bypasses
      // this rule entirely, so there is exactly one path by which this document is ever created.
    allow delete: if false; // deletion is handled by the deleteAccount callable, never a direct client delete (§7)

    match /private/profile {
      // PRIVATE document (§3.1) — this is the fix for the field-level-redaction problem: Firestore rules
      // can't return a subset of a document's fields, so anything SECURITY.md says must not be visible to
      // other users (phoneNumberHash, trustSignals, blockedUserIds, email, full verification detail) lives
      // in a document only the owner can read at all.
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && request.auth.uid == userId
                    && !request.resource.data.diff(resource.data)
                         .affectedKeys().hasAny(['trustSignals', 'verification', 'dateOfBirth', 'blockedUserIds', 'crewMemberships', 'subscription']);
        // a user may edit their own notification prefs / fcmTokens directly, but never their own trust
        // signals, verification record, self-reported date of birth (added Milestone F2 — a field that
        // gates a safety/legal requirement must not be editable by the account it belongs to once set,
        // same reasoning as `verification`), block list, crew-membership reverse-index, or subscription
        // state — Functions/Admin-SDK-only. `subscription` in particular must only ever move in response
        // to a verified Stripe webhook event (`stripeSubscriptionWebhook`), never a client write, so a
        // modified client can't grant itself TableCrew+ by writing `tier: "tablecrew_plus"` directly.
      allow create: if false;
        // Corrected in Milestone F2, same reasoning and same fix as the public document above: creation
        // is now exclusively via `completeAccountSetup` (API_SPEC.md §3.9), which is what makes the
        // dateOfBirth-gates-account-creation invariant actually enforceable — a rule alone cannot express
        // "reject this create() if the computed age is under 18," but a callable can, and only a callable
        // (Functions-only create) can be trusted to have actually run that check first.
      allow delete: if false;
    }

    match /photoModeration/{uploadId} {
      // Added Milestone F5, §3.1a above; path corrected from
      // `/private/photoModeration/{uploadId}` in task #97 — see §3.1a's correction note (the original
      // 5-segment path could never match a real document). The owner may READ their own upload's verdict
      // (Profile Setup listens here to know when to enable "Continue"), but every write comes from the
      // Storage-triggered moderation Function via the Admin SDK, which bypasses these rules entirely —
      // there is no client write path to this document at all, matching the "never trust the client for
      // this field" intent FIREBASE.md §2.5 states and completeAccountSetup (API_SPEC.md §3.9) now
      // actually enforces.
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow write: if false;
    }
  }

  match /tables/{tableId} {
    allow read: if resource.data.visibility == 'open'
                || (isSignedIn() && existsRsvpFor(tableId, request.auth.uid))
                || (isSignedIn() && resource.data.hostId == request.auth.uid);
      // Open Tables are publicly discoverable; Closed Tables are readable only by the host or an invited/requested user.
    allow create: if isSignedIn() && request.resource.data.hostId == request.auth.uid;
    allow update: if isSignedIn() && resource.data.hostId == request.auth.uid
                  && !request.resource.data.diff(resource.data)
                       .affectedKeys().hasAny(['capacity', 'reportFlags']);
      // only the host may edit a Table, and never its capacity counters or report flags directly —
      // those change only via callable functions using transactions / Admin SDK.

    match /rsvps/{rsvpUserId} {
      allow read: if isSignedIn() && (rsvpUserId == request.auth.uid || isTableHost(tableId));
      allow write: if false;
        // ALL RSVP writes go through callable functions (requestSeat, confirmAttendee, cancelTable),
        // never direct client writes — this is where the capacity invariant lives, and it must be
        // enforced inside a server-side transaction, not a security rule, because rules cannot
        // safely read-and-conditionally-write a *different* document (the parent Table's count)
        // atomically with this one.
    }
  }

  match /crews/{crewId} {
    allow read: if isSignedIn() && request.auth.uid in resource.data.memberIds;
    allow update: if isSignedIn() && request.auth.uid in resource.data.memberIds
                  && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['members']);
      // member list mutation goes through the addMember/removeMember callables (role checks, invite validation).

    match /messages/{messageId} {
      allow read: if isSignedIn() && request.auth.uid in get(/databases/$(database)/documents/crews/$(crewId)).data.memberIds;
      allow create: if isSignedIn() && request.auth.uid in get(...).data.memberIds
                    && request.resource.data.senderId == request.auth.uid;
      allow update, delete: if false; // chat messages are immutable once sent (moderation happens via reports, not edits)
    }
  }

  match /ratings/{ratingId} {
    allow create: if isSignedIn() && request.resource.data.raterId == request.auth.uid
                  && attendedTable(request.resource.data.tableId, request.auth.uid);
      // can only rate a Table you actually attended — checked against the RSVP subcollection.
    allow read: if isSignedIn() && (resource.data.raterId == request.auth.uid
                 || (resource.data.ratedUserId == request.auth.uid && resource.data.revealState == 'revealed'));
      // the rater can always read their own submitted rating; the rated party can only read it once
      // `revealState == 'revealed'` (§3.5) — this is the actual enforcement point for FR-T29a's simultaneous-reveal
      // requirement. An earlier version of this rule allowed `ratedUserId == request.auth.uid` unconditionally,
      // which would have let the rated party read the rater's score the instant it was created — the opposite of
      // what "simultaneous reveal" means. `revealState` flips via the Functions-only trigger/sweep described in §3.5,
      // never a client write, so a client cannot flip its own rating to "revealed" early.
    allow update: if false; // revealState/revealedAt transitions are Functions-only (Admin SDK bypasses rules)
    allow delete: if false; // ratings are immutable once submitted
  }

  match /tables/{tableId}/duressSignals/{userId} {
    allow read, write: if false; // Functions-only, per SECURITY.md — structurally unreadable by any client, including the triggering user
  }

  match /tables/{tableId}/locationShares/{shareId} {
    allow read, write: if false; // Functions-only; the trusted contact's view is served via a separate signed-link
                                 // HTTPS endpoint (API_SPEC.md), not a direct Firestore client read, since the
                                 // contact may not have a TableCrew account at all
  }

  match /reports/{reportId} {
    allow read, create, update, delete: if false;
      // Corrected 2026-08, Milestone F6: this used to allow a signed-in client to create() its own
      // report directly (checking only that reporterId matched the caller). That's the same category
      // of gap this document's own closing "structural principles" list (below) already names —
      // "anything with a cross-document invariant is rules-write-denied for clients, full stop" — a
      // client create() cannot enforce reportUser/reportTable's real validation: the per-user daily
      // rate limit (a sibling rateLimits/ document), the duplicate-open-report check (a query against
      // other reports documents), the reasonCode allowlist (flagged_media is system-only — a client
      // create() had no way to exclude it), or the report-threshold auto-suppression side effect on
      // the target. All of that only exists inside reportUser/reportTable's own Cloud Functions
      // handler (functions/src/trust/index.ts) — same Functions-only posture as duressSignals below,
      // and consistent with reports being "never client-readable, including by the reporter or the
      // reported party," which this rule already got right.
  }

  match /splitRequests/{splitRequestId} {
    allow read: if isSignedIn() && (resource.data.hostId == request.auth.uid
                 || request.auth.uid in resource.data.perAttendeeStatus);
      // a payer can see their own share and status; only the host sees the full split — never client-writable at all.
    allow write: if false; // exclusively written by createSplitRequest/confirmPayment/stripeWebhook via Admin SDK
  }

  match /idempotencyKeys/{idempotencyKey} {
    allow read, write: if false; // purely internal to Cloud Functions; no client path ever needs to touch this directly
  }

  match /venues/{venueId} {
    allow read: if true; // venue info is not sensitive and aids discovery even for signed-out marketing surfaces
    allow write: if false; // venues are managed exclusively via internal admin tooling / Functions
  }
}
```

Key structural principles this sketch encodes, generalized for reuse in every new collection we add:

1. **Anything with a cross-document invariant (capacity, ratings aggregates, trust signals) is rules-write-denied for clients**, full stop — it is only ever written by Cloud Functions using the Admin SDK, which is exempt from security rules by design. This is the single rule that most often needs re-explaining to new engineers: "why can't I just let the client increment this counter" — because rules cannot express "and also atomically update this sibling document," so the invariant would be racy.
2. **Read visibility for Closed vs. Open Tables is the primary safety-relevant rule in the schema**, since Discover (`ARCHITECTURE.md` §5.5) depends on Open Tables being broadly readable while Closed Tables must never leak to non-invitees — this is why `visibility` is a top-level Table field checked directly in rules rather than inferred.
3. **Reports and moderation data are structurally unreadable by any client role**, including the involved parties — this is enforced at the rules layer, not just at the application/UI layer, so there is no code path (including a bug in the app) that could leak a report to its subject.
4. **Immutability where the product doesn't need mutability** (chat messages, ratings) is enforced in rules, not just convention, which closes off an entire class of tampering/dispute scenarios by construction.
5. **Firestore rules cannot redact individual fields from a document read — a rule is document-granular, not field-granular.** Any collection with a mix of broadly-readable and owner-only fields (the `users` collection is the concrete case, §3.1) must be split into a public document and a private document (or subcollection); relying on "well, the sensitive field just won't be queried by honest clients" is not a security boundary, since any authenticated client can read a document's raw payload directly. We treat this as a standing design rule, not a one-off fix for `users`: the first question in reviewing a new collection's rules is "does every field allowed by the broadest `allow read` on this document actually need to be that broadly visible," and if not, split the document before shipping the rule.

## 7. Data Retention and Deletion (GDPR/CCPA-Style Requests)

Per `VALUES.md`'s "respect data like it's someone's actual life," deletion and export must be technically real, not a policy document that doesn't match what the system actually does.

**Account deletion (`deleteAccount` callable — not yet formally specified in `API_SPEC.md`; that's a tracked gap in `TASKS.md`, not a claim that the contract already exists there):**

- The user's `users/{userId}` (public) document is **not** hard-deleted immediately; it is marked `deletedAt` (soft delete) and PII-bearing fields (`displayName`, `photoUrl`, `bio`) are overwritten with tombstone values (e.g., `displayName: "Former Member"`, `photoUrl: null`) within the same callable invocation. The `users/{userId}/private/profile` document — which holds `phoneNumberHash`, `email`, `homeLocation`, `blockedUserIds`, `trustSignals`, and full `verification` detail (§3.1) — is **hard-deleted outright** in the same callable invocation rather than tombstoned, since nothing in it needs to survive for any other user's benefit once the safety-relevant counters have been folded into the retained aggregates described below; this makes deletion of directly-identifying and sensitive fields immediate and real, not eventually-consistent.
- **Denormalized snapshots the user no longer controls** (their `hostDisplayNameSnapshot` on past Tables, `userDisplayNameSnapshot` on past RSVPs and chat messages) are swept by a dedicated Cloud Function triggered by the `deletedAt` write, which patches every document we can enumerate as containing that user's denormalized PII (queried via the same `collectionGroup` and composite indexes used for normal reads, so this is not a fresh scan capability we'd need to build — it reuses Section 5's indexes) to the same tombstone values. This function is idempotent and re-runnable, so a partial failure (e.g., a timeout mid-sweep) can be safely retried to completion.
- **Cloud Storage photos** referenced by the deleted user are deleted directly (not just unlinked) as part of the same deletion workflow.
- **Firebase Auth record** is deleted last, once the Firestore/Storage sweep completes, so an in-flight sweep never loses the ability to identify which documents belonged to this uid.
- **What we intentionally retain, and why:** aggregate, de-identified counters that other users' safety depends on (e.g., a `reportCount` that contributed to another user's `trustSignals`, or a Rating document already delivered as an aggregate into someone else's `ratingAggregate`) are retained in de-identified/aggregate form — we do not unwind another user's trust signals just because the counterparty deleted their account, since that would let a bad actor erase their own safety history by deleting and recreating an account. This retention is scoped strictly to safety-relevant aggregates, not general profile data, and is documented as a policy exception in `SECURITY.md`.
- **Financial transaction records are the one deliberate, bounded exception to "real deletion means gone," and this is a legal requirement, not a design choice:** per `VALUES.md`, "real deletion" for personal data (profile, messages, RSVPs, location history) means immediate deletion/anonymization, but a minimum financial transaction ledger must be retained for the statutory tax/financial-recordkeeping period (~7 years) even after account deletion — most jurisdictions' tax and financial-recordkeeping law requires this, and no privacy regulation overrides it (GDPR Article 17(3)(b), for example, explicitly carves out retention needed for legal-obligation compliance). Concretely: the `splitRequests/{splitRequestId}` collection (§3.8) — the record of what was charged, to whom, how much, and the resulting Stripe PaymentIntent state — is **not deleted** when a party to it deletes their account. Instead, the `deleteAccount` callable's sweep, on encountering a `splitRequests` document referencing the deleting user (as `hostId` or in `perAttendeeStatus`), replaces that user's uid and any denormalized name/photo fields with an opaque, non-reversible token (e.g., `deleted-user-{hash}`), leaving `totalAmountCents`, `currency`, per-share amounts, timestamps, and Stripe PaymentIntent IDs intact. The document is then retained until the statutory retention period elapses, after which a scheduled function permanently deletes it. This is retention-with-anonymization, not full retention and not full deletion — anonymized wherever legally possible, retained only as long as legally required, exactly the distinction `VALUES.md` draws and that a blanket "we fully delete everything within X days" claim would falsely promise for this one collection.
- **Backups:** because scheduled Firestore exports (`ARCHITECTURE.md` §8) are point-in-time snapshots, a deletion request is not retroactively scrubbed from *already-taken* backups; our backup retention window (defined in `DEPLOYMENT.md`) is kept short enough that this is a bounded, disclosed exposure window consistent with regulatory guidance on backup data, rather than an indefinite one.

**Data export (right to access/portability):** a companion `exportUserData` callable assembles a JSON bundle of the user's own `users/{userId}` (public) and `users/{userId}/private/profile` documents, their RSVP history (via the `rsvps` collection-group query keyed to their uid), Ratings where they are `raterId` or `ratedUserId`, Crew memberships, and `splitRequests` documents where they are `hostId` or a payer, and delivers it via a signed, time-limited Cloud Storage download URL — using the same indexes and query patterns already in place for normal app function, so export is not a separate data pipeline that could drift out of sync with what the app actually stores.

**Retention defaults for non-deleted accounts:** Crew chat messages and RSVP history are retained indefinitely by default (they're low-sensitivity logistics data core to the product's own "past Tables" features), while raw verification artifacts (e.g., ID-verification provider responses, if temporarily cached en route to setting `verification.idVerified`) are never persisted in Firestore at all — they're handled transiently by the verification Cloud Function and only the boolean/tier result is stored, consistent with data minimization.

## 8. Cross-References

- Architectural rationale for Firestore choice, migration triggers, and Typesense sync mechanics: `ARCHITECTURE.md`.
- Callable function contracts that perform the transactional writes referenced throughout this document (`requestSeat`, `confirmAttendee`, `deleteAccount`, etc.): `API_SPEC.md`.
- Full security rules source and threat model: `SECURITY.md`.
- Backup schedule, retention windows, and RTO/RPO: `DEPLOYMENT.md`.
