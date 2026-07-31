import assert from 'node:assert/strict';
import {test} from 'node:test';

import {isWellFormedIdempotencyKey} from '../src/shared';

test('isWellFormedIdempotencyKey accepts a well-formed UUID v4', () => {
  assert.equal(
    isWellFormedIdempotencyKey('3fa85f64-5717-4562-b3fc-2c963f66afa6'),
    true,
  );
});

test('isWellFormedIdempotencyKey rejects a non-UUID string', () => {
  assert.equal(isWellFormedIdempotencyKey('not-a-uuid'), false);
});

test('isWellFormedIdempotencyKey rejects an empty string', () => {
  assert.equal(isWellFormedIdempotencyKey(''), false);
});

test('isWellFormedIdempotencyKey rejects non-string input', () => {
  assert.equal(isWellFormedIdempotencyKey(12345), false);
  assert.equal(isWellFormedIdempotencyKey(undefined), false);
  assert.equal(isWellFormedIdempotencyKey(null), false);
});
