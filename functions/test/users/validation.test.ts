import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {
  isValidBio,
  isValidDisplayName,
  isValidInterestTags,
  isValidLocale,
} from '../../src/users/validation';

describe('isValidDisplayName', () => {
  it('accepts a normal name', () => {
    assert.equal(isValidDisplayName('Priya K.'), true);
  });

  it('rejects an empty string', () => {
    assert.equal(isValidDisplayName(''), false);
  });

  it('rejects a whitespace-only string', () => {
    assert.equal(isValidDisplayName('   '), false);
  });

  it('accepts exactly 30 characters', () => {
    assert.equal(isValidDisplayName('a'.repeat(30)), true);
  });

  it('rejects 31 characters', () => {
    assert.equal(isValidDisplayName('a'.repeat(31)), false);
  });

  it('rejects a non-string value', () => {
    assert.equal(isValidDisplayName(123), false);
    assert.equal(isValidDisplayName(null), false);
    assert.equal(isValidDisplayName(undefined), false);
  });
});

describe('isValidBio', () => {
  it('accepts null (optional field)', () => {
    assert.equal(isValidBio(null), true);
  });

  it('accepts undefined (optional field)', () => {
    assert.equal(isValidBio(undefined), true);
  });

  it('accepts an empty string', () => {
    assert.equal(isValidBio(''), true);
  });

  it('accepts exactly 140 characters', () => {
    assert.equal(isValidBio('a'.repeat(140)), true);
  });

  it('rejects 141 characters', () => {
    assert.equal(isValidBio('a'.repeat(141)), false);
  });

  it('rejects a non-string, non-null/undefined value', () => {
    assert.equal(isValidBio(42), false);
  });
});

describe('isValidInterestTags', () => {
  it('accepts exactly 3 tags', () => {
    assert.equal(isValidInterestTags(['hiking', 'coffee', 'board-games']), true);
  });

  it('accepts more than 3 tags', () => {
    assert.equal(isValidInterestTags(['a', 'b', 'c', 'd']), true);
  });

  it('rejects fewer than 3 tags', () => {
    assert.equal(isValidInterestTags(['a', 'b']), false);
  });

  it('rejects an empty array', () => {
    assert.equal(isValidInterestTags([]), false);
  });

  it('rejects a non-array value', () => {
    assert.equal(isValidInterestTags('hiking,coffee,wine'), false);
  });

  it('rejects an array containing a non-string element', () => {
    assert.equal(isValidInterestTags(['a', 'b', 42]), false);
  });

  it('rejects an array containing an empty-string element', () => {
    assert.equal(isValidInterestTags(['a', 'b', '']), false);
  });
});

describe('isValidLocale', () => {
  it('accepts a bare language subtag', () => {
    assert.equal(isValidLocale('en'), true);
  });

  it('accepts language-region', () => {
    assert.equal(isValidLocale('en-IN'), true);
  });

  it('accepts a 3-letter language subtag', () => {
    assert.equal(isValidLocale('eng'), true);
  });

  it('rejects an empty string', () => {
    assert.equal(isValidLocale(''), false);
  });

  it('rejects a too-short subtag', () => {
    assert.equal(isValidLocale('e'), false);
  });

  it('rejects an overly long, malformed value', () => {
    assert.equal(isValidLocale('english'), false);
  });

  it('rejects a non-string value', () => {
    assert.equal(isValidLocale(null), false);
  });
});
