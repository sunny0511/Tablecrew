import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  isValidCapacity,
  isValidDescription,
  isValidInterestTag,
  isValidLocation,
  isValidStartTime,
  isValidTitle,
  isValidVisibility,
  validateTablePatch,
} from '../../src/tables/validation';

test('isValidTitle accepts 1-100 characters, rejects empty/too-long/non-string', () => {
  assert.equal(isValidTitle('Sunday hike'), true);
  assert.equal(isValidTitle('a'), true);
  assert.equal(isValidTitle('a'.repeat(100)), true);
  assert.equal(isValidTitle(''), false);
  assert.equal(isValidTitle('a'.repeat(101)), false);
  assert.equal(isValidTitle(123), false);
  assert.equal(isValidTitle(undefined), false);
});

test('isValidDescription allows null/undefined, enforces the 1000-char ceiling', () => {
  assert.equal(isValidDescription(null), true);
  assert.equal(isValidDescription(undefined), true);
  assert.equal(isValidDescription('a'.repeat(1000)), true);
  assert.equal(isValidDescription('a'.repeat(1001)), false);
  assert.equal(isValidDescription(42), false);
});

test('isValidInterestTag allows null/undefined, accepts only known tags', () => {
  assert.equal(isValidInterestTag(null), true);
  assert.equal(isValidInterestTag(undefined), true);
  assert.equal(isValidInterestTag('dinner'), true);
  assert.equal(isValidInterestTag('board_games'), true);
  assert.equal(isValidInterestTag('not_a_real_tag'), false);
  assert.equal(isValidInterestTag(''), false);
});

test('isValidVisibility only accepts the two documented enum values', () => {
  assert.equal(isValidVisibility('open'), true);
  assert.equal(isValidVisibility('closed'), true);
  assert.equal(isValidVisibility('public'), false);
  assert.equal(isValidVisibility(undefined), false);
});

test('isValidLocation requires a valid-or-null geopoint and non-empty address', () => {
  assert.equal(
      isValidLocation({geopoint: {lat: 17.385, lng: 78.4867}, address: '123 Main St'}),
      true,
  );
  assert.equal(
      isValidLocation({geopoint: {lat: 17.385, lng: 78.4867}, venueId: 'v1', address: '123 Main St'}),
      true,
  );
  // F6 correction: a manual-entry venue (Screen 11's fallback) has a name
  // and address but no coordinates - geopoint null is now a valid shape.
  assert.equal(
      isValidLocation({geopoint: null, venueName: 'Broadway Cafe', address: '123 Main St'}),
      true,
      'manual-entry venue: null geopoint with venueName',
  );
  assert.equal(
      isValidLocation({geopoint: {lat: 17.385, lng: 78.4867}, venueName: 'Broadway Cafe', address: '123 Main St'}),
      true,
      'venueName alongside a real geopoint',
  );
  assert.equal(isValidLocation(null), false);
  assert.equal(isValidLocation({}), false, 'address still required even with geopoint omitted');
  assert.equal(isValidLocation({geopoint: {lat: 91, lng: 0}, address: 'x'}), false, 'lat out of range');
  assert.equal(isValidLocation({geopoint: {lat: 0, lng: 181}, address: 'x'}), false, 'lng out of range');
  assert.equal(isValidLocation({geopoint: {lat: 0, lng: 0}, address: ''}), false, 'empty address');
  assert.equal(isValidLocation({geopoint: {lat: 0, lng: 0}, address: '   '}), false, 'whitespace-only address');
  assert.equal(
      isValidLocation({geopoint: {lat: 0, lng: 0}, venueId: 42, address: 'x'}),
      false,
      'venueId must be a string when present',
  );
  assert.equal(
      isValidLocation({geopoint: null, venueName: 42, address: 'x'}),
      false,
      'venueName must be a string when present',
  );
});

test('isValidStartTime requires more than 1 hour of lead time', () => {
  const in2Hours = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
  const in30Minutes = new Date(Date.now() + 30 * 60 * 1000).toISOString();

  assert.equal(isValidStartTime(in2Hours), true);
  assert.equal(isValidStartTime(in30Minutes), false);
  assert.equal(isValidStartTime('not-a-date'), false);
  assert.equal(isValidStartTime(undefined), false);
});

test('isValidCapacity enforces 2 <= min <= max <= 8', () => {
  assert.equal(isValidCapacity({min: 2, max: 8}), true);
  assert.equal(isValidCapacity({min: 4, max: 4}), true);
  assert.equal(isValidCapacity({min: 1, max: 4}), false, 'below the hard floor');
  assert.equal(isValidCapacity({min: 4, max: 9}), false, 'above the hard ceiling');
  assert.equal(isValidCapacity({min: 5, max: 4}), false, 'min > max');
  assert.equal(isValidCapacity({min: 2.5, max: 4}), false, 'non-integer');
  assert.equal(isValidCapacity(null), false);
});

test('validateTablePatch only checks keys actually present, per its own Partial<> contract', () => {
  assert.deepEqual(validateTablePatch({title: 'New title'}), []);
  assert.deepEqual(validateTablePatch({}), [], 'an empty patch has nothing to reject');
});

test('validateTablePatch rejects each invalid field by name, ignoring valid ones in the same patch', () => {
  const result = validateTablePatch({
    title: 'Valid title',
    description: 'a'.repeat(1001),
    visibility: 'not-a-real-value',
  });

  assert.deepEqual(result.sort(), ['description', 'visibility']);
});

test('validateTablePatch treats a non-object patch as fully invalid', () => {
  assert.deepEqual(validateTablePatch(null), ['patch']);
  assert.deepEqual(validateTablePatch('not-an-object'), ['patch']);
  assert.deepEqual(validateTablePatch(undefined), ['patch']);
});
