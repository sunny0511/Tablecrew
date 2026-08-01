import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  CREW_MEMBER_SOFT_CAP,
  isValidCrewName,
  isValidCrewPhotoUrl,
  isValidInitialMemberIds,
  validateCrewPatch,
} from '../../src/crews/validation';

test('isValidCrewName accepts 1-40 characters, rejects empty/too-long/non-string', () => {
  assert.equal(isValidCrewName('Sunday Hike Crew'), true);
  assert.equal(isValidCrewName('a'), true);
  assert.equal(isValidCrewName('a'.repeat(40)), true);
  assert.equal(isValidCrewName(''), false);
  assert.equal(isValidCrewName('   '), false, 'whitespace-only trims to empty');
  assert.equal(isValidCrewName('a'.repeat(41)), false);
  assert.equal(isValidCrewName(42), false);
  assert.equal(isValidCrewName(undefined), false);
});

test('isValidCrewPhotoUrl allows null/undefined, rejects empty string and non-string', () => {
  assert.equal(isValidCrewPhotoUrl(null), true);
  assert.equal(isValidCrewPhotoUrl(undefined), true);
  assert.equal(isValidCrewPhotoUrl('https://example.com/photo.jpg'), true);
  assert.equal(isValidCrewPhotoUrl(''), false);
  assert.equal(isValidCrewPhotoUrl(42), false);
});

test('isValidInitialMemberIds allows undefined, accepts an array of non-empty uid strings', () => {
  assert.equal(isValidInitialMemberIds(undefined), true);
  assert.equal(isValidInitialMemberIds([]), true);
  assert.equal(isValidInitialMemberIds(['uid-1', 'uid-2']), true);
  assert.equal(isValidInitialMemberIds('not-an-array'), false);
  assert.equal(isValidInitialMemberIds(['uid-1', '']), false, 'empty-string uid');
  assert.equal(isValidInitialMemberIds(['uid-1', 42]), false, 'non-string entry');
  assert.equal(isValidInitialMemberIds(null), false);
});

test('validateCrewPatch only checks keys actually present, per its own Partial<> contract', () => {
  assert.deepEqual(validateCrewPatch({name: 'New name'}), []);
  assert.deepEqual(validateCrewPatch({}), [], 'an empty patch has nothing to reject');
});

test('validateCrewPatch rejects each invalid field by name, ignoring valid ones in the same patch', () => {
  const result = validateCrewPatch({
    name: 'a'.repeat(41),
    photoUrl: '',
  });

  assert.deepEqual(result.sort(), ['name', 'photoUrl']);
});

test('validateCrewPatch treats a non-object patch as fully invalid', () => {
  assert.deepEqual(validateCrewPatch(null), ['patch']);
  assert.deepEqual(validateCrewPatch('not-an-object'), ['patch']);
  assert.deepEqual(validateCrewPatch(undefined), ['patch']);
});

test('CREW_MEMBER_SOFT_CAP is a positive integer', () => {
  assert.ok(Number.isInteger(CREW_MEMBER_SOFT_CAP));
  assert.ok(CREW_MEMBER_SOFT_CAP > 0);
});
