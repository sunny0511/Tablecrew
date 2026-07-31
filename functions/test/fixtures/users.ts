/**
 * docs/DATABASE.md §3.1 - users/{userId} (public) and
 * users/{userId}/private/profile. See docs/TESTING.md's "Test Data
 * Management and Fixtures" section: this is the canonical fixtures library
 * for Cloud Functions unit tests going forward (Milestone F4+), built here
 * in Milestone F1 alongside the schema it mirrors.
 *
 * Note: firestore/test/rules/src/fixtures.ts has its own small,
 * independently-maintained set of builders for rules-emulator tests only -
 * that package has no monorepo workspace wiring to import this module
 * across the package boundary without coupling two independently-versioned
 * dependency trees together. Both are kept in sync with docs/DATABASE.md
 * by hand; a schema change updates both, same as any other cross-document
 * consistency requirement in this repository.
 */

export interface TestUserPublic {
  displayName: string;
  photoUrl: string | null;
  bio: string | null;
  interestTags: string[];
  verificationTierPublic: string;
  ratingAggregate: {
    averageAsHost: number | null;
    averageAsAttendee: number | null;
    ratingCountAsHost: number;
    ratingCountAsAttendee: number;
  };
  locale: string;
  deletedAt: number | null;
  createdAt: number;
  updatedAt: number;
}

export interface TestUserPrivateProfile {
  phoneNumberHash: string;
  email: string | null;
  homeLocation: null;
  residencyRegion: string;
  verification: {
    phoneVerified: boolean;
    idVerified: boolean;
    verificationTier: string;
    verifiedAt: number | null;
  };
  trustSignals: {
    reportCount: number;
    noShowCount: number;
    substantiatedBillingDisputeCount: number;
    standingStatus: string;
  };
  blockedUserIds: string[];
  notificationPrefs: {
    categories: Record<string, boolean>;
    mutedCrewIds: string[];
  };
  subscription: {
    tier: string;
    status: string;
    stripeCustomerId: string | null;
    stripeSubscriptionId: string | null;
    currentPeriodEnd: number | null;
    cancelAtPeriodEnd: boolean;
    updatedAt: number;
  };
  fcmTokens: unknown[];
  crewMemberships: string[];
  createdAt: number;
  updatedAt: number;
}

export interface TestUser {
  uid: string;
  public: TestUserPublic;
  private: TestUserPrivateProfile;
}

/**
 * Builds a schema-accurate synthetic user (both the public profile document
 * and the private/profile document), for use in Cloud Functions unit tests
 * and dev-emulator seeding (see scripts/seed_dev.ts). Override just the
 * fields relevant to a given test via the `overrides` parameter rather than
 * hand-rolling a full user object inline.
 */
export function buildTestUser(overrides: {
  uid?: string;
  public?: Partial<TestUserPublic>;
  private?: Partial<TestUserPrivateProfile>;
} = {}): TestUser {
  const now = Date.now();
  const uid = overrides.uid ?? `test-user-${now}`;
  return {
    uid,
    public: {
      displayName: 'Test User',
      photoUrl: null,
      bio: null,
      interestTags: [],
      verificationTierPublic: 'phone_verified',
      ratingAggregate: {
        averageAsHost: null,
        averageAsAttendee: null,
        ratingCountAsHost: 0,
        ratingCountAsAttendee: 0,
      },
      locale: 'en-IN',
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      ...overrides.public,
    },
    private: {
      phoneNumberHash: `test-hash-${uid}`,
      email: null,
      homeLocation: null,
      residencyRegion: 'IN',
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
      ...overrides.private,
    },
  };
}
