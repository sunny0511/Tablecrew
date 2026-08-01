/**
 * User domain: account creation & signup (Tier 1), session revocation. See
 * docs/API_SPEC.md §3.9 (`validateAge`, `completeAccountSetup`) and §3.8
 * (`revokeSessions`).
 *
 * Added Milestone F2 — this directory did not exist before. Closes a real
 * gap docs/ENGINEERING_GUIDELINES.md's repository-structure section already
 * claimed was true ("The `functions/src/` structure mirrors the Firestore
 * collections described in `DATABASE.md` (Users, Tables, Crews, RSVPs,
 * Ratings, Reports, Venues)") but which the scaffolded tree never actually
 * had a `users/` folder for.
 *
 * Known gap, disclosed rather than silently skipped: docs/API_SPEC.md §5's
 * cross-cutting per-user/per-endpoint-family rate limiting (a Firestore-
 * backed sliding-window counter) is not implemented in any of these three
 * callables yet. No domain in this codebase has that infra built yet
 * either — it's a shared mechanism that makes more sense to build once,
 * generically, alongside the first Milestone F4 endpoints that need it at
 * real scale, than to bespoke-implement three times over for this
 * milestone's three callables. Tracked in TASKS.md, not silently omitted.
 *
 * Uses the modular firebase-admin/{app,auth,firestore} imports rather than
 * the old `import * as admin from 'firebase-admin'` namespaced style —
 * firebase-admin 14.2.0 (bumped from 12.6.0 this milestone, see TASKS.md)
 * removes `admin.firestore()`/`admin.auth()`/`admin.firestore.FieldValue`
 * from the namespaced export entirely, a genuine breaking change a real
 * `tsc` build caught, not a style choice.
 *
 * `enforceAppCheck` below is `ENFORCE_APP_CHECK`, not a bare `true` —
 * real emulator testing (functions/test/integration/) found that a
 * missing App Check token gets rejected with a deliberately generic
 * `HttpsError('unauthenticated', 'Unauthenticated')`, not a distinguishable
 * App-Check-specific error (Firebase's own design, to avoid leaking which
 * layer — Auth or App Check — rejected a request). Since there is no App
 * Check emulator anywhere in the Firebase Emulator Suite, enforcing it
 * unconditionally would make every callable permanently untestable
 * against a local emulator, not just in this repo's test suite but for
 * any future local development against these functions. `FUNCTIONS_EMULATOR`
 * is a real, framework-set env var (`true` inside the Functions emulator's
 * own process, unset in a real deployment) — this is the standard,
 * documented way to tell the two environments apart, not a workaround
 * specific to this codebase.
 */

import * as crypto from 'node:crypto';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {isEligibleAge, isWellFormedDateOfBirth} from './ageGate';
import {deriveResidencyRegion} from './residency';
import {isValidBio, isValidDisplayName, isValidInterestTags, isValidLocale} from './validation';

const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== 'true';

function hashPhoneNumber(phoneE164: string): string {
  return crypto.createHash('sha256').update(phoneE164).digest('hex');
}

interface ValidateAgeRequest {
  dateOfBirth?: unknown;
}

/**
 * docs/API_SPEC.md §3.9 — fast, non-persisting eligibility check backing
 * Screen 4 (Date of Birth Entry)'s "Continue" round trip. Writes nothing;
 * the real, authoritative age check happens again at `completeAccountSetup`
 * below, never trusted from this call alone (docs/SECURITY.md: "not solely
 * a client-side gate, since client clocks/logic can be manipulated" applies
 * equally to trusting an earlier server call's result over re-checking).
 */
export const validateAge = onCall<ValidateAgeRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }

      const {dateOfBirth} = request.data ?? {};
      if (!isWellFormedDateOfBirth(dateOfBirth)) {
        throw new HttpsError(
            'invalid-argument',
            'dateOfBirth must be a well-formed, non-future ISO 8601 date.',
        );
      }

      return {eligible: isEligibleAge(dateOfBirth)};
    },
);

interface CompleteAccountSetupRequest {
  dateOfBirth?: unknown;
  displayName?: unknown;
  photoUploadId?: unknown;
  bio?: unknown;
  interestTags?: unknown;
  locale?: unknown;
}

/**
 * docs/API_SPEC.md §3.9 — the only path by which `users/{uid}` and
 * `users/{uid}/private/profile` are ever created; `firestore.rules` denies
 * direct client `create()` for both as of Milestone F2, specifically so
 * this callable's server-side 18+ re-check cannot be bypassed.
 */
export const completeAccountSetup = onCall<CompleteAccountSetupRequest>(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }
      const uid = request.auth.uid;

      const {dateOfBirth, displayName, photoUploadId, bio, interestTags, locale} =
        request.data ?? {};

      if (!isWellFormedDateOfBirth(dateOfBirth)) {
        throw new HttpsError(
            'invalid-argument',
            'dateOfBirth must be a well-formed, non-future ISO 8601 date.',
        );
      }
      if (!isValidDisplayName(displayName)) {
        throw new HttpsError('invalid-argument', 'displayName must be 1-30 characters.');
      }
      if (!isValidBio(bio)) {
        throw new HttpsError('invalid-argument', 'bio must be at most 140 characters.');
      }
      if (!isValidInterestTags(interestTags)) {
        throw new HttpsError('invalid-argument', 'interestTags requires at least 3 tags.');
      }
      if (!isValidLocale(locale)) {
        throw new HttpsError('invalid-argument', 'locale must be a valid BCP-47 locale tag.');
      }
      if (
        photoUploadId !== undefined &&
        photoUploadId !== null &&
        typeof photoUploadId !== 'string'
      ) {
        throw new HttpsError('invalid-argument', 'photoUploadId must be a string or null.');
      }

      // The actual enforcement point (docs/SECURITY.md's age-gating
      // section) — validateAge above is a UX convenience only and is never
      // trusted as having already established this.
      if (!isEligibleAge(dateOfBirth)) {
        throw new HttpsError(
            'failed-precondition',
            'Account creation requires an age of 18 or older.',
            {code: 'UNDER_MINIMUM_AGE', message: 'You must be 18 or older to create a TableCrew account.'},
        );
      }

      const db = getFirestore();
      const publicRef = db.doc(`users/${uid}`);
      const privateRef = db.doc(`users/${uid}/private/profile`);

      // Idempotent-by-construction (docs/API_SPEC.md §3.9): the caller can
      // only ever create their own uid's documents, so an existing document
      // here means this is a genuine retry of this same one-time action,
      // not a different caller's conflict — return success with the
      // existing data rather than erroring.
      const existingPublicDoc = await publicRef.get();
      if (existingPublicDoc.exists) {
        const data = existingPublicDoc.data();
        return {
          uid,
          verificationTierPublic: (data && data.verificationTierPublic) || 'phone_verified',
        };
      }

      // Corrected 2026-08, Milestone F5: this used to take a raw
      // client-supplied `photoUrl` string on faith. It now re-derives the
      // real URL itself from the moderation-verdict document the
      // Storage-triggered moderation Function wrote (docs/DATABASE.md
      // §3.1a, docs/FIREBASE.md §2.5, ADR 0006) — `photoUploadId` is only
      // ever used as a lookup key into a document this server already
      // trusts, never as a source of the URL value directly. Because the
      // lookup path is always `users/${uid}/...` (the caller's own uid,
      // server-derived from the auth token, never client input), there is
      // no way for a client to reference another uid's upload.
      let photoUrl: string | null = null;
      if (typeof photoUploadId === 'string') {
        const moderationDoc = await db
            .doc(`users/${uid}/private/photoModeration/${photoUploadId}`)
            .get();
        const moderationData = moderationDoc.data();
        if (
          !moderationDoc.exists ||
          moderationData?.status !== 'approved' ||
          typeof moderationData?.approvedUrl !== 'string'
        ) {
          throw new HttpsError(
              'failed-precondition',
              'The referenced photo has not passed moderation review.',
              {
                code: 'PHOTO_NOT_APPROVED',
                message: 'That photo isn\'t ready yet — try again in a moment, or pick another.',
              },
          );
        }
        photoUrl = moderationData.approvedUrl;
      }

      const now = FieldValue.serverTimestamp();
      const phoneNumber = request.auth.token.phone_number;
      const phoneNumberHash = typeof phoneNumber === 'string' ?
        hashPhoneNumber(phoneNumber) :
        hashPhoneNumber(uid);
      const residencyRegion = typeof phoneNumber === 'string' ?
        deriveResidencyRegion(phoneNumber) :
        'IN';

      const batch = db.batch();

      batch.create(publicRef, {
        displayName,
        photoUrl: photoUrl ?? null,
        bio: bio ?? null,
        interestTags,
        verificationTierPublic: 'phone_verified',
        ratingAggregate: {
          averageAsHost: null,
          averageAsAttendee: null,
          ratingCountAsHost: 0,
          ratingCountAsAttendee: 0,
        },
        locale,
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      });

      batch.create(privateRef, {
        phoneNumberHash,
        email: null,
        homeLocation: null,
        residencyRegion,
        dateOfBirth,
        verification: {
          phoneVerified: true,
          idVerified: false,
          verificationTier: 'phone_verified',
          verifiedAt: now,
        },
        trustSignals: {
          reportCount: 0,
          noShowCount: 0,
          substantiatedBillingDisputeCount: 0,
          standingStatus: 'good',
        },
        blockedUserIds: [],
        notificationPrefs: {
          categories: {
            rsvp_updates: true,
            waitlist_promotion: true,
            chat_messages: true,
            crew_recurrence_nudges: true,
            billing: true,
            discover_matches: true,
          },
          mutedCrewIds: [],
        },
        subscription: {
          tier: 'free',
          status: 'none',
          stripeCustomerId: null,
          stripeSubscriptionId: null,
          currentPeriodEnd: null,
          cancelAtPeriodEnd: false,
          updatedAt: now,
        },
        fcmTokens: [],
        crewMemberships: [],
        createdAt: now,
        updatedAt: now,
      });

      try {
        await batch.commit();
      } catch (err) {
        // A create()-on-existing-document race (two near-simultaneous
        // retries) surfaces here as a commit failure - treat it the same
        // idempotent-by-construction way as the pre-check above, rather
        // than letting a narrow timing window turn into a client-facing
        // error for what is still just a retry of the same one-time action.
        const existing = await publicRef.get();
        if (existing.exists) {
          const data = existing.data();
          return {uid, verificationTierPublic: (data && data.verificationTierPublic) || 'phone_verified'};
        }
        throw err;
      }

      return {uid, verificationTierPublic: 'phone_verified'};
    },
);

/**
 * docs/API_SPEC.md §3.8 — "sign out everywhere." Invalidates every
 * outstanding refresh token for the caller's own uid.
 */
export const revokeSessions = onCall(
    {enforceAppCheck: ENFORCE_APP_CHECK},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Sign-in required.');
      }

      await getAuth().revokeRefreshTokens(request.auth.uid);

      return {success: true, revokedAt: new Date().toISOString()};
    },
);
