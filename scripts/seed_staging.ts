/**
 * scripts/seed_staging.ts
 *
 * Populates the **staging** Firebase project with a realistic but entirely
 * synthetic set of Users, Crews, and Tables, per docs/TESTING.md's "Test
 * Data Management and Fixtures" section ("we maintain a small seed script
 * (scripts/seed_staging.ts) that populates a realistic but synthetic set of
 * users, Tables, and Crews, so staging is never empty") and
 * docs/DEPLOYMENT.md's staging-environment description. Referenced by name
 * in both documents before this file existed - this closes that gap.
 *
 * This is a deliberately standalone script, not a consumer of the shared
 * fixtures library at functions/test/fixtures/ (docs/TESTING.md's other
 * named fixtures location) - that library is a separate, independently-
 * versioned npm package (functions/) with no monorepo workspace wiring to
 * import across the package boundary cheaply, the same reasoning documented
 * in firestore/test/rules/src/fixtures.ts. A handful of hand-written,
 * schema-accurate synthetic records is enough for what this script needs
 * (staging should simply never be empty), so duplicating a small, self-
 * contained data set here - rather than adding a third copy of a shared
 * builder library, or coupling this script's dependency tree to functions/'s
 * - is the lower-complexity choice for a script this narrowly scoped.
 *
 * SAFETY: this script writes real documents to a real Firebase project (not
 * the emulator - staging is a real, deployed environment per
 * docs/DEPLOYMENT.md). It refuses to run against anything other than the
 * `tablecrew-staging` project, and requires an explicit --yes flag, so it
 * can never be accidentally pointed at `tablecrew-prod` or run without
 * confirmation - consistent with docs/VALUES.md's "respect data like it's
 * someone's actual life" applying even to how we generate *fake* data.
 *
 * Usage (once functions/-style `npm install` has been run in this
 * directory, and `gcloud auth application-default login` or
 * GOOGLE_APPLICATION_CREDENTIALS is configured for the staging project):
 *
 *   npm run seed:staging -- --project=tablecrew-staging --yes
 *
 * All seeded documents use deterministic `seed-*` IDs, so re-running this
 * script overwrites the same synthetic records rather than accumulating
 * duplicates on every run.
 */

import * as admin from 'firebase-admin';

const REQUIRED_PROJECT_ID = 'tablecrew-staging';

function parseArgs(argv: string[]): {project: string | null; confirmed: boolean} {
  let project: string | null = null;
  let confirmed = false;
  for (const arg of argv) {
    if (arg.startsWith('--project=')) {
      project = arg.slice('--project='.length);
    } else if (arg === '--yes') {
      confirmed = true;
    }
  }
  return {project, confirmed};
}

function buildSeedUsers(now: number) {
  return [
    {
      uid: 'seed-user-priya',
      public: {
        displayName: 'Priya K.',
        photoUrl: null,
        bio: 'Loves board game nights and finding good filter coffee.',
        interestTags: ['board-games', 'coffee'],
        verificationTierPublic: 'phone_verified',
        ratingAggregate: {averageAsHost: null, averageAsAttendee: null, ratingCountAsHost: 0, ratingCountAsAttendee: 0},
        locale: 'en-IN',
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      },
      private: {
        phoneNumberHash: 'seed-hash-priya',
        email: null,
        homeLocation: null,
        residencyRegion: 'IN',
        verification: {phoneVerified: true, idVerified: false, verificationTier: 'phone_verified', verifiedAt: now},
        trustSignals: {reportCount: 0, noShowCount: 0, substantiatedBillingDisputeCount: 0, standingStatus: 'good'},
        blockedUserIds: [],
        notificationPrefs: {
          categories: {rsvp_updates: true, waitlist_promotion: true, chat_messages: true, crew_recurrence_nudges: true, billing: true, discover_matches: true},
          mutedCrewIds: [],
        },
        subscription: {tier: 'free', status: 'none', stripeCustomerId: null, stripeSubscriptionId: null, currentPeriodEnd: null, cancelAtPeriodEnd: false, updatedAt: now},
        fcmTokens: [],
        crewMemberships: ['seed-crew-hiking'],
        createdAt: now,
        updatedAt: now,
      },
    },
    {
      uid: 'seed-user-arjun',
      public: {
        displayName: 'Arjun M.',
        photoUrl: null,
        bio: 'Weekend hiker, always up for a new trail.',
        interestTags: ['hiking', 'photography'],
        verificationTierPublic: 'phone_verified',
        ratingAggregate: {averageAsHost: null, averageAsAttendee: null, ratingCountAsHost: 0, ratingCountAsAttendee: 0},
        locale: 'en-IN',
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      },
      private: {
        phoneNumberHash: 'seed-hash-arjun',
        email: null,
        homeLocation: null,
        residencyRegion: 'IN',
        verification: {phoneVerified: true, idVerified: false, verificationTier: 'phone_verified', verifiedAt: now},
        trustSignals: {reportCount: 0, noShowCount: 0, substantiatedBillingDisputeCount: 0, standingStatus: 'good'},
        blockedUserIds: [],
        notificationPrefs: {
          categories: {rsvp_updates: true, waitlist_promotion: true, chat_messages: true, crew_recurrence_nudges: true, billing: true, discover_matches: true},
          mutedCrewIds: [],
        },
        subscription: {tier: 'free', status: 'none', stripeCustomerId: null, stripeSubscriptionId: null, currentPeriodEnd: null, cancelAtPeriodEnd: false, updatedAt: now},
        fcmTokens: [],
        crewMemberships: ['seed-crew-hiking'],
        createdAt: now,
        updatedAt: now,
      },
    },
    {
      uid: 'seed-user-fatima',
      public: {
        displayName: 'Fatima R.',
        photoUrl: null,
        bio: 'Runs a monthly dinner club for old friends.',
        interestTags: ['dinner', 'wine'],
        verificationTierPublic: 'phone_verified',
        ratingAggregate: {averageAsHost: null, averageAsAttendee: null, ratingCountAsHost: 0, ratingCountAsAttendee: 0},
        locale: 'en-IN',
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      },
      private: {
        phoneNumberHash: 'seed-hash-fatima',
        email: null,
        homeLocation: null,
        residencyRegion: 'IN',
        verification: {phoneVerified: true, idVerified: false, verificationTier: 'phone_verified', verifiedAt: now},
        trustSignals: {reportCount: 0, noShowCount: 0, substantiatedBillingDisputeCount: 0, standingStatus: 'good'},
        blockedUserIds: [],
        notificationPrefs: {
          categories: {rsvp_updates: true, waitlist_promotion: true, chat_messages: true, crew_recurrence_nudges: true, billing: true, discover_matches: true},
          mutedCrewIds: [],
        },
        subscription: {tier: 'free', status: 'none', stripeCustomerId: null, stripeSubscriptionId: null, currentPeriodEnd: null, cancelAtPeriodEnd: false, updatedAt: now},
        fcmTokens: [],
        crewMemberships: [],
        createdAt: now,
        updatedAt: now,
      },
    },
  ];
}

function buildSeedCrews(now: number) {
  return [
    {
      id: 'seed-crew-hiking',
      name: 'Weekend Trail Crew',
      photoUrl: null,
      creatorId: 'seed-user-arjun',
      memberIds: ['seed-user-arjun', 'seed-user-priya'],
      members: {
        'seed-user-arjun': {displayNameSnapshot: 'Arjun M.', photoUrlSnapshot: null, role: 'admin', joinedAt: now},
        'seed-user-priya': {displayNameSnapshot: 'Priya K.', photoUrlSnapshot: null, role: 'member', joinedAt: now},
      },
      tableHistoryCount: 0,
      recurrence: {cadence: 'biweekly', dayOfWeek: 'saturday', nextSuggestedAt: now + 7 * 86400000},
      createdAt: now,
      updatedAt: now,
    },
  ];
}

function buildSeedTables(now: number) {
  return [
    {
      id: 'seed-table-hike',
      hostId: 'seed-user-arjun',
      hostDisplayNameSnapshot: 'Arjun M.',
      hostPhotoUrlSnapshot: null,
      hostVerificationTierSnapshot: 'phone_verified',
      title: 'Saturday morning hike + brunch',
      interestTag: 'hiking',
      description: 'Easy 5k trail, brunch after at the usual spot.',
      costBand: '$$',
      coverPhotoUrl: null,
      accessibilityNotes: 'Moderate terrain, not step-free.',
      visibility: 'closed',
      status: 'filling',
      location: {geopoint: null, venueId: null, venueNameSnapshot: null, address: null, isTBD: true, tbdConfirmBy: now + 2 * 86400000},
      startTime: now + 3 * 86400000,
      capacity: {min: 2, max: 6, confirmedCount: 2, waitlistCount: 0},
      crewId: 'seed-crew-hiking',
      priceSplitEnabled: false,
      reportFlags: {openReportCount: 0, isSuppressed: false},
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'seed-table-dinner',
      hostId: 'seed-user-fatima',
      hostDisplayNameSnapshot: 'Fatima R.',
      hostPhotoUrlSnapshot: null,
      hostVerificationTierSnapshot: 'phone_verified',
      title: 'Monthly dinner club',
      interestTag: 'dinner',
      description: 'Small dinner, bring a bottle if you like.',
      costBand: '$$$',
      coverPhotoUrl: null,
      accessibilityNotes: null,
      visibility: 'closed',
      status: 'proposed',
      location: {geopoint: null, venueId: null, venueNameSnapshot: null, address: null, isTBD: true, tbdConfirmBy: now + 5 * 86400000},
      startTime: now + 6 * 86400000,
      capacity: {min: 4, max: 8, confirmedCount: 0, waitlistCount: 0},
      crewId: null,
      priceSplitEnabled: false,
      reportFlags: {openReportCount: 0, isSuppressed: false},
      createdAt: now,
      updatedAt: now,
    },
  ];
}

async function main(): Promise<void> {
  const {project, confirmed} = parseArgs(process.argv.slice(2));

  if (project !== REQUIRED_PROJECT_ID) {
    console.error(
        `Refusing to run: this script only seeds the '${REQUIRED_PROJECT_ID}' project. ` +
        `Pass --project=${REQUIRED_PROJECT_ID} explicitly (got: ${project ?? '(none)'}). ` +
        'This script never runs against tablecrew-dev or tablecrew-prod.',
    );
    process.exitCode = 1;
    return;
  }

  if (!confirmed) {
    console.error(
        'Refusing to run without --yes. Re-run with --yes to actually write ' +
        `synthetic seed data to the real '${REQUIRED_PROJECT_ID}' project.`,
    );
    process.exitCode = 1;
    return;
  }

  admin.initializeApp({projectId: project});
  const db = admin.firestore();
  const now = Date.now();

  const batch = db.batch();

  for (const user of buildSeedUsers(now)) {
    batch.set(db.doc(`users/${user.uid}`), user.public);
    batch.set(db.doc(`users/${user.uid}/private/profile`), user.private);
  }

  for (const crew of buildSeedCrews(now)) {
    const {id, ...crewData} = crew;
    batch.set(db.doc(`crews/${id}`), crewData);
  }

  for (const table of buildSeedTables(now)) {
    const {id, ...tableData} = table;
    batch.set(db.doc(`tables/${id}`), tableData);
  }

  await batch.commit();

  console.log(
      `Seeded ${REQUIRED_PROJECT_ID}: ${buildSeedUsers(now).length} users, ` +
      `${buildSeedCrews(now).length} crew(s), ${buildSeedTables(now).length} table(s). ` +
      'Re-run any time - all IDs are deterministic (seed-*), so this overwrites rather than duplicates.',
  );
}

main().catch((err) => {
  console.error('seed_staging failed:', err);
  process.exitCode = 1;
});
