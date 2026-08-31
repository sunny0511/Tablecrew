import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  KNOWN_DOCUMENT_TYPES,
  buildIdentityUploadPath,
  isValidDecision,
  isValidDocumentType,
  isValidRejectionReason,
  isValidUploadId,
  resolveReviewOutcome,
} from '../../src/identity/validation';

test('isValidDocumentType accepts every known type and rejects anything else', () => {
  for (const type of KNOWN_DOCUMENT_TYPES) {
    assert.equal(isValidDocumentType(type), true, `${type} should be valid`);
  }
  assert.equal(isValidDocumentType('aadhaar'), false);
  assert.equal(isValidDocumentType(''), false);
  assert.equal(isValidDocumentType(undefined), false);
  assert.equal(isValidDocumentType(42), false);
});

test('isValidUploadId rejects anything that could escape the caller\'s own Storage prefix', () => {
  // The whole point of this validator. Milestone F6's triggerDuressSignal
  // crash came from building a path out of an unvalidated id; a separator
  // here would be worse than a crash, since it would address someone
  // else's object.
  assert.equal(isValidUploadId('a1b2c3-d4e5'), true);
  assert.equal(isValidUploadId('upload_1.jpg'), true);

  assert.equal(isValidUploadId('../other-user/id'), false);
  assert.equal(isValidUploadId('nested/path'), false);
  assert.equal(isValidUploadId('..'), false);
  assert.equal(isValidUploadId('.'), false);
  assert.equal(isValidUploadId('a..b'), false);
  assert.equal(isValidUploadId('has space'), false);
  assert.equal(isValidUploadId('semi;colon'), false);
});

test('isValidUploadId rejects empty, oversized, and non-string ids', () => {
  assert.equal(isValidUploadId(''), false);
  assert.equal(isValidUploadId('a'.repeat(129)), false);
  assert.equal(isValidUploadId('a'.repeat(128)), true);
  assert.equal(isValidUploadId(undefined), false);
  assert.equal(isValidUploadId(null), false);
  assert.equal(isValidUploadId(123), false);
});

test('buildIdentityUploadPath roots every object under the caller\'s own uid', () => {
  assert.equal(
      buildIdentityUploadPath('alice', 'id-1'),
      'identity-verifications/alice/id-1',
  );
});

test('isValidDecision accepts only approve and reject', () => {
  assert.equal(isValidDecision('approve'), true);
  assert.equal(isValidDecision('reject'), true);
  assert.equal(isValidDecision('hold'), false);
  assert.equal(isValidDecision(''), false);
  assert.equal(isValidDecision(undefined), false);
});

test('isValidRejectionReason requires real, bounded, non-whitespace text', () => {
  assert.equal(isValidRejectionReason('The ID photo is too blurry to read.'), true);
  assert.equal(isValidRejectionReason(''), false);
  assert.equal(isValidRejectionReason('   '), false);
  assert.equal(isValidRejectionReason('x'.repeat(501)), false);
  assert.equal(isValidRejectionReason('x'.repeat(500)), true);
  assert.equal(isValidRejectionReason(undefined), false);
});

test('resolveReviewOutcome: a reject with a usable reason rejects, and trims it', () => {
  assert.deepEqual(
      resolveReviewOutcome({
        decision: 'reject',
        dobMatchesId: false,
        rejectionReason: '  Photo is unreadable.  ',
        hasOpenReport: false,
      }),
      {kind: 'rejected', reason: 'Photo is unreadable.'},
  );
});

test('resolveReviewOutcome: a reject with no usable reason is invalid, not a silent rejection', () => {
  for (const reason of [undefined, '', '   ', 42]) {
    assert.deepEqual(
        resolveReviewOutcome({
          decision: 'reject',
          dobMatchesId: false,
          rejectionReason: reason,
          hasOpenReport: false,
        }),
        {kind: 'invalid', code: 'REJECTION_REASON_REQUIRED'},
    );
  }
});

test('resolveReviewOutcome: an approve without the DOB attestation never grants the tier', () => {
  // docs/SECURITY.md requires the ID/DOB cross-check before Tier 2 is
  // granted. With no OCR under ADR 0007 this is the only thing standing
  // in for it, so it must be impossible to skip by omission.
  assert.deepEqual(
      resolveReviewOutcome({
        decision: 'approve',
        dobMatchesId: false,
        hasOpenReport: false,
      }),
      {kind: 'invalid', code: 'DOB_ATTESTATION_REQUIRED'},
  );
});

test('resolveReviewOutcome: a missing attestation outranks an open report', () => {
  // Ordering matters: a decision with no attestation is malformed, which
  // is a different thing from a well-formed decision that gets held.
  assert.deepEqual(
      resolveReviewOutcome({
        decision: 'approve',
        dobMatchesId: false,
        hasOpenReport: true,
      }),
      {kind: 'invalid', code: 'DOB_ATTESTATION_REQUIRED'},
  );
});

test('resolveReviewOutcome: an open report at apply time holds the grant', () => {
  assert.deepEqual(
      resolveReviewOutcome({
        decision: 'approve',
        dobMatchesId: true,
        hasOpenReport: true,
      }),
      {kind: 'held_for_review'},
  );
});

test('resolveReviewOutcome: a clean approve grants', () => {
  assert.deepEqual(
      resolveReviewOutcome({
        decision: 'approve',
        dobMatchesId: true,
        hasOpenReport: false,
      }),
      {kind: 'approved'},
  );
});
