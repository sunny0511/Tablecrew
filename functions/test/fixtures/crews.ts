/** docs/DATABASE.md §3.4 - crews/{crewId}. See users.ts for the fixtures-library note. */

export interface TestCrewMemberSnapshot {
  displayNameSnapshot: string;
  photoUrlSnapshot: string | null;
  role: 'admin' | 'member';
  joinedAt: number;
}

export interface TestCrew {
  name: string;
  photoUrl: string | null;
  creatorId: string;
  memberIds: string[];
  members: Record<string, TestCrewMemberSnapshot>;
  tableHistoryCount: number;
  recurrence: null;
  createdAt: number;
  updatedAt: number;
}

export function buildTestCrew(overrides: Partial<TestCrew> = {}): TestCrew {
  const now = Date.now();
  return {
    name: 'Test Crew',
    photoUrl: null,
    creatorId: 'test-creator',
    memberIds: ['test-creator'],
    members: {
      'test-creator': {displayNameSnapshot: 'Test Creator', photoUrlSnapshot: null, role: 'admin', joinedAt: now},
    },
    tableHistoryCount: 0,
    recurrence: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}
