/** docs/DATABASE.md §3.3 - tables/{tableId}/rsvps/{userId}. See users.ts for the fixtures-library note. */

export interface TestRsvp {
  userId: string;
  userDisplayNameSnapshot: string;
  userPhotoUrlSnapshot: string | null;
  status: 'invited' | 'requested' | 'confirmed' | 'declined' | 'waitlisted' | 'attended' | 'no_show';
  statusHistory: Array<{status: string; at: number}>;
  respondedAt: number | null;
  splitPaymentStatus: 'not_applicable' | 'pending' | 'paid' | 'failed' | 'disputed' | null;
  createdAt: number;
  updatedAt: number;
}

export function buildTestRsvp(overrides: Partial<TestRsvp> = {}): TestRsvp {
  const now = Date.now();
  return {
    userId: 'test-attendee',
    userDisplayNameSnapshot: 'Test Attendee',
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
