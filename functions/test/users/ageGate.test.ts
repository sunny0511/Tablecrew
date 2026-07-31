import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {computeAgeAsOf, isEligibleAge, isWellFormedDateOfBirth} from '../../src/users/ageGate';

// Fixed "now" so these tests never depend on the wall-clock date.
const NOW = new Date(Date.UTC(2026, 6, 31)); // 2026-07-31

describe('isWellFormedDateOfBirth', () => {
  it('accepts a well-formed past date', () => {
    assert.equal(isWellFormedDateOfBirth('2000-06-15', NOW), true);
  });

  it('accepts a date equal to today (not future)', () => {
    assert.equal(isWellFormedDateOfBirth('2026-07-31', NOW), true);
  });

  it('rejects a date in the future', () => {
    assert.equal(isWellFormedDateOfBirth('2026-08-01', NOW), false);
  });

  it('rejects a non-existent calendar date (Feb 30)', () => {
    assert.equal(isWellFormedDateOfBirth('2023-02-30', NOW), false);
  });

  it('accepts Feb 29 on a real leap year', () => {
    assert.equal(isWellFormedDateOfBirth('2000-02-29', NOW), true);
  });

  it('rejects Feb 29 on a non-leap year', () => {
    assert.equal(isWellFormedDateOfBirth('2001-02-29', NOW), false);
  });

  it('rejects a wrong-shaped string (DD-MM-YYYY)', () => {
    assert.equal(isWellFormedDateOfBirth('15-06-2000', NOW), false);
  });

  it('rejects a non-string input', () => {
    assert.equal(isWellFormedDateOfBirth(20000615, NOW), false);
    assert.equal(isWellFormedDateOfBirth(null, NOW), false);
    assert.equal(isWellFormedDateOfBirth(undefined, NOW), false);
  });
});

describe('computeAgeAsOf', () => {
  it('computes exactly 18 on the 18th birthday itself', () => {
    assert.equal(computeAgeAsOf('2008-07-31', NOW), 18);
  });

  it('computes 17 the day before the 18th birthday', () => {
    assert.equal(computeAgeAsOf('2008-08-01', NOW), 17);
  });

  it('computes 18 the day after the 18th birthday', () => {
    assert.equal(computeAgeAsOf('2008-07-30', NOW), 18);
  });

  it('treats a leap-day (Feb 29) birthday as not-yet-had on Feb 28 of a non-leap year', () => {
    const feb28NonLeap = new Date(Date.UTC(2026, 1, 28));
    assert.equal(computeAgeAsOf('2008-02-29', feb28NonLeap), 17);
  });

  it('treats a leap-day (Feb 29) birthday as had by March 1 of a non-leap year', () => {
    const mar1NonLeap = new Date(Date.UTC(2026, 2, 1));
    assert.equal(computeAgeAsOf('2008-02-29', mar1NonLeap), 18);
  });
});

describe('isEligibleAge', () => {
  it('is eligible at exactly 18', () => {
    assert.equal(isEligibleAge('2008-07-31', NOW), true);
  });

  it('is not eligible at 17', () => {
    assert.equal(isEligibleAge('2008-08-01', NOW), false);
  });

  it('is eligible well over 18', () => {
    assert.equal(isEligibleAge('1990-01-01', NOW), true);
  });
});
