import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  CLIENT_REPORT_REASON_CODES,
  extractDuressLocation,
  isValidBlockTargetUserId,
  isValidReportDetails,
  isValidReportReasonCode,
  isValidReportTargetType,
  isValidTargetId,
} from '../../src/trust/validation';

test('CLIENT_REPORT_REASON_CODES excludes the system-only flagged_media value', () => {
  assert.equal(CLIENT_REPORT_REASON_CODES.has('flagged_media'), false);
});

test('isValidReportReasonCode accepts only the client-submittable enum, rejects flagged_media and non-strings', () => {
  assert.equal(isValidReportReasonCode('safety_concern'), true);
  assert.equal(isValidReportReasonCode('no_show'), true);
  assert.equal(isValidReportReasonCode('harassment'), true);
  assert.equal(isValidReportReasonCode('fake_profile'), true);
  assert.equal(isValidReportReasonCode('off_platform_stalking'), true);
  assert.equal(isValidReportReasonCode('other'), true);
  assert.equal(isValidReportReasonCode('flagged_media'), false);
  assert.equal(isValidReportReasonCode('not_a_real_reason'), false);
  assert.equal(isValidReportReasonCode(undefined), false);
  assert.equal(isValidReportReasonCode(42), false);
});

test('isValidReportTargetType only accepts "user" or "table"', () => {
  assert.equal(isValidReportTargetType('user'), true);
  assert.equal(isValidReportTargetType('table'), true);
  assert.equal(isValidReportTargetType('venue'), false);
  assert.equal(isValidReportTargetType(undefined), false);
});

test('isValidTargetId requires a non-empty, non-whitespace-only string', () => {
  assert.equal(isValidTargetId('user-123'), true);
  assert.equal(isValidTargetId(''), false);
  assert.equal(isValidTargetId('   '), false);
  assert.equal(isValidTargetId(undefined), false);
  assert.equal(isValidTargetId(42), false);
});

test('isValidReportDetails requires non-empty details for off_platform_stalking, allows null/undefined otherwise', () => {
  assert.equal(isValidReportDetails('off_platform_stalking', 'they followed me to my car'), true);
  assert.equal(isValidReportDetails('off_platform_stalking', ''), false);
  assert.equal(isValidReportDetails('off_platform_stalking', '   '), false);
  assert.equal(isValidReportDetails('off_platform_stalking', null), false);
  assert.equal(isValidReportDetails('off_platform_stalking', undefined), false);

  assert.equal(isValidReportDetails('no_show', null), true);
  assert.equal(isValidReportDetails('no_show', undefined), true);
  assert.equal(isValidReportDetails('no_show', 'ran 40 minutes late, no message'), true);
});

test('isValidReportDetails enforces the 1000-char ceiling and rejects non-strings', () => {
  assert.equal(isValidReportDetails('other', 'a'.repeat(1000)), true);
  assert.equal(isValidReportDetails('other', 'a'.repeat(1001)), false);
  assert.equal(isValidReportDetails('other', 42), false);
});

test('isValidBlockTargetUserId rejects blocking yourself and non-strings', () => {
  assert.equal(isValidBlockTargetUserId('bob', 'alice'), true);
  assert.equal(isValidBlockTargetUserId('alice', 'alice'), false);
  assert.equal(isValidBlockTargetUserId('', 'alice'), false);
  assert.equal(isValidBlockTargetUserId(undefined, 'alice'), false);
});

test('extractDuressLocation returns a valid {lat,lng} pair from a well-formed payload', () => {
  assert.deepEqual(
      extractDuressLocation({geopoint: {lat: 17.385, lng: 78.4867}}),
      {lat: 17.385, lng: 78.4867},
  );
});

test('extractDuressLocation never throws, returns null for any malformed/missing shape', () => {
  assert.equal(extractDuressLocation(undefined), null);
  assert.equal(extractDuressLocation(null), null);
  assert.equal(extractDuressLocation({}), null);
  assert.equal(extractDuressLocation({geopoint: null}), null);
  assert.equal(extractDuressLocation({geopoint: {}}), null);
  assert.equal(extractDuressLocation({geopoint: {lat: 'not a number', lng: 78.4867}}), null);
  assert.equal(extractDuressLocation({geopoint: {lat: 200, lng: 78.4867}}), null);
  assert.equal(extractDuressLocation({geopoint: {lat: 17.385, lng: -200}}), null);
  assert.equal(extractDuressLocation('a string'), null);
});
