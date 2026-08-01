import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {
  approvedObjectPath,
  classifySafeSearchVerdict,
  parsePendingProfilePhotoPath,
} from '../../src/media/moderation';

describe('classifySafeSearchVerdict', () => {
  it('approves a clean image (all UNLIKELY)', () => {
    const verdict = classifySafeSearchVerdict({
      adult: 'VERY_UNLIKELY',
      violence: 'UNLIKELY',
      racy: 'UNLIKELY',
      medical: 'UNLIKELY',
      spoof: 'UNLIKELY',
    });
    assert.deepEqual(verdict, {status: 'approved', flagReason: null});
  });

  it('approves when every field is absent (defaults to UNKNOWN)', () => {
    const verdict = classifySafeSearchVerdict({});
    assert.deepEqual(verdict, {status: 'approved', flagReason: null});
  });

  it('flags adult content at LIKELY', () => {
    const verdict = classifySafeSearchVerdict({adult: 'LIKELY'});
    assert.equal(verdict.status, 'flagged');
    assert.equal(verdict.flagReason, 'adult:LIKELY');
  });

  it('flags adult content at VERY_LIKELY', () => {
    const verdict = classifySafeSearchVerdict({adult: 'VERY_LIKELY'});
    assert.equal(verdict.status, 'flagged');
  });

  it('does not flag adult content at POSSIBLE (below the LIKELY threshold)', () => {
    const verdict = classifySafeSearchVerdict({adult: 'POSSIBLE'});
    assert.equal(verdict.status, 'approved');
  });

  it('flags violence at LIKELY', () => {
    const verdict = classifySafeSearchVerdict({violence: 'LIKELY'});
    assert.equal(verdict.status, 'flagged');
    assert.equal(verdict.flagReason, 'violence:LIKELY');
  });

  it('does not flag violence at POSSIBLE', () => {
    const verdict = classifySafeSearchVerdict({violence: 'POSSIBLE'});
    assert.equal(verdict.status, 'approved');
  });

  it('does NOT flag racy content at LIKELY (deliberately permissive threshold)', () => {
    const verdict = classifySafeSearchVerdict({racy: 'LIKELY'});
    assert.equal(verdict.status, 'approved');
  });

  it('flags racy content only at VERY_LIKELY', () => {
    const verdict = classifySafeSearchVerdict({racy: 'VERY_LIKELY'});
    assert.equal(verdict.status, 'flagged');
    assert.equal(verdict.flagReason, 'racy:VERY_LIKELY');
  });

  it('never flags on medical or spoof alone, regardless of likelihood', () => {
    const verdict = classifySafeSearchVerdict({
      medical: 'VERY_LIKELY',
      spoof: 'VERY_LIKELY',
    });
    assert.equal(verdict.status, 'approved');
  });

  it('checks adult before violence before racy when multiple are high (first match wins)', () => {
    const verdict = classifySafeSearchVerdict({
      adult: 'LIKELY',
      violence: 'VERY_LIKELY',
      racy: 'VERY_LIKELY',
    });
    assert.equal(verdict.flagReason, 'adult:LIKELY');
  });

  it('treats null the same as UNKNOWN/absent', () => {
    const verdict = classifySafeSearchVerdict({adult: null, violence: null, racy: null});
    assert.equal(verdict.status, 'approved');
  });
});

describe('parsePendingProfilePhotoPath', () => {
  it('parses a well-formed pending profile-photo path', () => {
    const result = parsePendingProfilePhotoPath('users/uid123/profile/pending/upload-abc');
    assert.deepEqual(result, {userId: 'uid123', uploadId: 'upload-abc'});
  });

  it('parses an uploadId that includes a file extension', () => {
    const result = parsePendingProfilePhotoPath('users/uid123/profile/pending/abc-123.jpg');
    assert.deepEqual(result, {userId: 'uid123', uploadId: 'abc-123.jpg'});
  });

  it('returns null for the approved/ path (must not re-trigger on its own output)', () => {
    const result = parsePendingProfilePhotoPath('users/uid123/profile/approved/upload-abc');
    assert.equal(result, null);
  });

  it('returns null for a Table cover-photo path (not built until F6+)', () => {
    const result = parsePendingProfilePhotoPath('tables/table1/photos/pending/upload-abc');
    assert.equal(result, null);
  });

  it('returns null for an unrelated top-level path', () => {
    assert.equal(parsePendingProfilePhotoPath('some/other/path.jpg'), null);
  });

  it('returns null for a path missing the uploadId segment', () => {
    assert.equal(parsePendingProfilePhotoPath('users/uid123/profile/pending/'), null);
  });
});

describe('approvedObjectPath', () => {
  it('builds the expected approved/ path', () => {
    assert.equal(
        approvedObjectPath('uid123', 'upload-abc'),
        'users/uid123/profile/approved/upload-abc',
    );
  });
});
