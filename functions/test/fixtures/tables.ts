/** docs/DATABASE.md §3.2 - tables/{tableId}. See users.ts for the fixtures-library note. */

export interface TestTable {
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
  status: 'proposed' | 'filling' | 'confirmed' | 'happened' | 'rated' | 'cancelled';
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

/**
 * Builds a schema-accurate synthetic Table, defaulting to a Closed Table
 * (Milestone F1/Foundation's in-scope visibility per
 * docs/IMPLEMENTATION_PLAN.md's Crew-first sequencing) with a 2-8 hard
 * headcount range default of min 2 / max 8 per docs/PRODUCT.md.
 */
export function buildTestTable(overrides: Partial<TestTable> = {}): TestTable {
  const now = Date.now();
  return {
    hostId: 'test-host',
    hostDisplayNameSnapshot: 'Test Host',
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
