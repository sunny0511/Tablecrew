/** docs/DATABASE.md §3.9 - idempotencyKeys/{idempotencyKey}. See users.ts for the fixtures-library note. */

export interface TestIdempotencyKey {
  uid: string;
  endpoint: string;
  status: 'in_progress' | 'completed';
  response: Record<string, unknown> | null;
  createdAt: number;
  expiresAt: number;
}

export function buildTestIdempotencyKey(overrides: Partial<TestIdempotencyKey> = {}): TestIdempotencyKey {
  const now = Date.now();
  return {
    uid: 'test-user',
    endpoint: 'requestSeat',
    status: 'in_progress',
    response: null,
    createdAt: now,
    expiresAt: now + 86400000,
    ...overrides,
  };
}
