/**
 * Minimal, schema-shaped fixture builders for Firestore rules tests only.
 *
 * These are deliberately not the same fixtures library docs/TESTING.md's
 * "Test Data Management and Fixtures" section describes
 * (`functions/test/fixtures/`, used by Cloud Functions business-logic unit
 * tests) - that library lives in a sibling, independently-versioned npm
 * package with its own node_modules, and this package (firestore/test/rules)
 * has no monorepo workspace wiring to import TypeScript source across
 * package boundaries without coupling their dependency trees together. Rules
 * tests only need schema-shaped plain objects to seed via the admin bypass
 * context and to exercise specific rule branches - they don't need the
 * richer business-logic-aware fixtures the Functions test suite uses, so a
 * small, self-contained set of builders here is the lower-coupling choice,
 * not a duplicated oversight. Every field below matches docs/DATABASE.md's
 * schema for the collection it builds.
 */

export interface UserPublicFixture {
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

/** docs/DATABASE.md §3.1 - users/{userId} (public profile). */
export function buildUserPublicFixture(
    overrides: Partial<UserPublicFixture> = {},
): UserPublicFixture {
  const now = Date.now();
  return {
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
    locale: 'en-US',
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

export interface UserPrivateProfileFixture {
  phoneNumberHash: string;
  email: string | null;
  homeLocation: null;
  residencyRegion: string;
  dateOfBirth: string;
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

/** docs/DATABASE.md §3.1 - users/{userId}/private/profile. */
export function buildUserPrivateProfileFixture(
    overrides: Partial<UserPrivateProfileFixture> = {},
): UserPrivateProfileFixture {
  const now = Date.now();
  return {
    phoneNumberHash: 'test-hash',
    email: null,
    homeLocation: null,
    residencyRegion: 'IN',
    dateOfBirth: '2000-06-15',
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
    ...overrides,
  };
}

export interface PhotoModerationFixture {
  status: 'pending' | 'approved' | 'flagged';
  approvedUrl: string | null;
  flagReason: string | null;
  storagePath: string;
  createdAt: number;
}

/** docs/DATABASE.md §3.1a - users/{userId}/photoModeration/{uploadId}
 * (Milestone F5, path corrected in task #97 - see that section's
 * correction note). */
export function buildPhotoModerationFixture(
    overrides: Partial<PhotoModerationFixture> = {},
): PhotoModerationFixture {
  return {
    status: 'approved',
    approvedUrl: 'https://firebasestorage.googleapis.com/v0/b/test/o/approved%2Fupload-1?alt=media&token=t',
    flagReason: null,
    storagePath: 'users/alice/profile/pending/upload-1',
    createdAt: Date.now(),
    ...overrides,
  };
}

export interface TableFixture {
  hostId: string;
  hostDisplayNameSnapshot: string;
  hostPhotoUrlSnapshot: string | null;
  hostVerificationTierSnapshot: string;
  title: string;
  interestTag: string | null;
  description: string | null;
  costBand: string | null;
  coverPhotoUrl: string | null;
  accessibilityNotes: string | null;
  visibility: 'open' | 'closed';
  status: string;
  location: {
    geopoint: null;
    venueId: string | null;
    venueNameSnapshot: string | null;
    address: string | null;
    isTBD: boolean;
    tbdConfirmBy: number | null;
  };
  startTime: number;
  capacity: {
    min: number;
    max: number;
    confirmedCount: number;
    waitlistCount: number;
  };
  crewId: string | null;
  priceSplitEnabled: boolean;
  reportFlags: {
    openReportCount: number;
    isSuppressed: boolean;
  };
  createdAt: number;
  updatedAt: number;
}

/** docs/DATABASE.md §3.2 - tables/{tableId}. */
export function buildTableFixture(
    overrides: Partial<TableFixture> = {},
): TableFixture {
  const now = Date.now();
  return {
    hostId: 'alice',
    hostDisplayNameSnapshot: 'Alice',
    hostPhotoUrlSnapshot: null,
    hostVerificationTierSnapshot: 'phone_verified',
    title: 'Test Table',
    interestTag: null,
    description: null,
    costBand: null,
    coverPhotoUrl: null,
    accessibilityNotes: null,
    visibility: 'closed',
    status: 'proposed',
    location: {
      geopoint: null,
      venueId: null,
      venueNameSnapshot: null,
      address: null,
      isTBD: true,
      tbdConfirmBy: null,
    },
    startTime: now + 86400000,
    capacity: {
      min: 2,
      max: 8,
      confirmedCount: 0,
      waitlistCount: 0,
    },
    crewId: null,
    priceSplitEnabled: false,
    reportFlags: {
      openReportCount: 0,
      isSuppressed: false,
    },
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

export interface RsvpFixture {
  userId: string;
  userDisplayNameSnapshot: string;
  userPhotoUrlSnapshot: string | null;
  status: string;
  statusHistory: Array<{status: string; at: number}>;
  respondedAt: number | null;
  splitPaymentStatus: string | null;
  createdAt: number;
  updatedAt: number;
}

/** docs/DATABASE.md §3.3 - tables/{tableId}/rsvps/{userId}. */
export function buildRsvpFixture(
    overrides: Partial<RsvpFixture> = {},
): RsvpFixture {
  const now = Date.now();
  return {
    userId: 'bob',
    userDisplayNameSnapshot: 'Bob',
    userPhotoUrlSnapshot: null,
    status: 'confirmed',
    statusHistory: [{status: 'confirmed', at: now}],
    respondedAt: now,
    splitPaymentStatus: 'not_applicable',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

export interface CrewFixture {
  name: string;
  photoUrl: string | null;
  creatorId: string;
  memberIds: string[];
  members: Record<string, {
    displayNameSnapshot: string;
    photoUrlSnapshot: string | null;
    role: 'admin' | 'member';
    joinedAt: number;
  }>;
  tableHistoryCount: number;
  recurrence: null;
  createdAt: number;
  updatedAt: number;
}

/** docs/DATABASE.md §3.4 - crews/{crewId}. */
export function buildCrewFixture(
    overrides: Partial<CrewFixture> = {},
): CrewFixture {
  const now = Date.now();
  return {
    name: 'Test Crew',
    photoUrl: null,
    creatorId: 'alice',
    memberIds: ['alice', 'bob'],
    members: {
      alice: {displayNameSnapshot: 'Alice', photoUrlSnapshot: null, role: 'admin', joinedAt: now},
      bob: {displayNameSnapshot: 'Bob', photoUrlSnapshot: null, role: 'member', joinedAt: now},
    },
    tableHistoryCount: 0,
    recurrence: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

export interface ReportFixture {
  reporterId: string;
  targetType: 'user' | 'table';
  targetId: string;
  reasonCode: string;
  severity: string | null;
  isDuressSignal: boolean;
  details: string | null;
  status: string;
  assignedTo: string | null;
  resolutionNotes: string | null;
  createdAt: number;
  updatedAt: number;
}

/** docs/DATABASE.md §3.6 - reports/{reportId} (Milestone F6). */
export function buildReportFixture(
    overrides: Partial<ReportFixture> = {},
): ReportFixture {
  const now = Date.now();
  return {
    reporterId: 'alice',
    targetType: 'user',
    targetId: 'bob',
    reasonCode: 'harassment',
    severity: null,
    isDuressSignal: false,
    details: null,
    status: 'open',
    assignedTo: null,
    resolutionNotes: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

export interface DuressSignalFixture {
  triggeredAt: number;
  lastKnownLocation: null;
  status: string;
  linkedReportId: string | null;
  acknowledgedBy: string | null;
}

/** docs/DATABASE.md §3.3a - tables/{tableId}/duressSignals/{userId}
 * (Milestone F6). */
export function buildDuressSignalFixture(
    overrides: Partial<DuressSignalFixture> = {},
): DuressSignalFixture {
  return {
    triggeredAt: Date.now(),
    lastKnownLocation: null,
    status: 'open',
    linkedReportId: null,
    acknowledgedBy: null,
    ...overrides,
  };
}

export interface IdempotencyKeyFixture {
  uid: string;
  endpoint: string;
  status: string;
  response: null;
  createdAt: number;
  expiresAt: number;
}

/** docs/DATABASE.md §3.9 - idempotencyKeys/{idempotencyKey}. */
export function buildIdempotencyKeyFixture(
    overrides: Partial<IdempotencyKeyFixture> = {},
): IdempotencyKeyFixture {
  const now = Date.now();
  return {
    uid: 'alice',
    endpoint: 'requestSeat',
    status: 'in_progress',
    response: null,
    createdAt: now,
    expiresAt: now + 86400000,
    ...overrides,
  };
}

/**
 * A Tier 2 identity-verification submission (docs/DATABASE.md §3.10,
 * Milestone F7). Shaped as the pending_review state, since that is the only
 * state a client could ever plausibly try to read or tamper with — a
 * terminal-status document is equally unreachable under the same rules.
 */
export function buildIdentityVerificationFixture(
    overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    userId: 'alice',
    status: 'pending_review',
    documentType: 'aadhaar_offline',
    idDocumentPath: 'identity-verifications/alice/id-1',
    selfiePath: 'identity-verifications/alice/selfie-1',
    dobMatchesId: null,
    reviewedBy: null,
    reviewedAt: null,
    decisionReason: null,
    createdAt: new Date('2026-08-31T00:00:00Z'),
    updatedAt: new Date('2026-08-31T00:00:00Z'),
    ...overrides,
  };
}
