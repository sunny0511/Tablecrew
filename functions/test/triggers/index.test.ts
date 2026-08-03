import assert from 'node:assert/strict';
import {test} from 'node:test';
import {GeoPoint} from 'firebase-admin/firestore';
import {deriveTypesenseDocument} from '../../src/triggers';

const NOW = new Date('2026-08-02T12:00:00.000Z').getTime();
const FUTURE = {toMillis: () => NOW + 60 * 60 * 1000};
const PAST = {toMillis: () => NOW - 60 * 60 * 1000};

function baseTableData(overrides: Record<string, unknown> = {}) {
  return {
    title: 'Sunday hike',
    hostDisplayNameSnapshot: 'Alice',
    interestTag: 'hiking',
    visibility: 'open',
    status: 'proposed',
    costBand: '$$',
    location: {
      // A real GeoPoint instance, not a hand-rolled {lat, lng} shape —
      // this is deliberate: a plain fake object here is exactly what let
      // this file's very first version pass against the wrong
      // `.lat`/`.lng` property names, a real bug only the Firestore-
      // emulator-backed integration test actually caught (see
      // functions/src/triggers/index.ts's inline note).
      geopoint: new GeoPoint(17.385, 78.4867),
      venueNameSnapshot: 'Golconda Fort',
    },
    startTime: FUTURE,
    createdAt: PAST,
    capacity: {max: 8, confirmedCount: 2},
    reportFlags: {isSuppressed: false},
    ...overrides,
  };
}

test('deriveTypesenseDocument: an eligible Open Table derives a full document', () => {
  const doc = deriveTypesenseDocument('t1', baseTableData(), NOW);

  assert.ok(doc);
  assert.equal(doc!.id, 't1');
  assert.equal(doc!.title, 'Sunday hike');
  assert.equal(doc!.hostDisplayNameSnapshot, 'Alice');
  assert.equal(doc!.interestTag, 'hiking');
  assert.deepEqual(doc!.location, [17.385, 78.4867]);
  assert.equal(doc!.venueNameSnapshot, 'Golconda Fort');
  assert.equal(doc!.costBand, '$$');
  assert.equal(doc!.startTime, Math.floor((NOW + 60 * 60 * 1000) / 1000));
  assert.equal(doc!.capacityMax, 8);
  assert.equal(doc!.seatsRemaining, 6);
  assert.equal(doc!.createdAt, Math.floor((NOW - 60 * 60 * 1000) / 1000));
});

test('deriveTypesenseDocument: returns null for a Table with no document at all (deleted)', () => {
  assert.equal(deriveTypesenseDocument('t1', undefined, NOW), null);
});

test('deriveTypesenseDocument: returns null for a Closed Table', () => {
  const data = baseTableData({visibility: 'closed'});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: returns null for a cancelled Table, even with a future startTime', () => {
  const data = baseTableData({status: 'cancelled'});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: returns null for a suppressed Table (reportFlags.isSuppressed)', () => {
  const data = baseTableData({reportFlags: {isSuppressed: true}});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: returns null for a full Table (confirmedCount >= max)', () => {
  const data = baseTableData({capacity: {max: 8, confirmedCount: 8}});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: returns null once startTime is in the past', () => {
  const data = baseTableData({startTime: PAST});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: returns null for a Table with no geopoint yet (TBD/manual-entry-pending location)', () => {
  const data = baseTableData({location: {geopoint: null, venueNameSnapshot: null}});
  assert.equal(deriveTypesenseDocument('t1', data, NOW), null);
});

test('deriveTypesenseDocument: missing optional fields (venueNameSnapshot, costBand) default to empty strings, not undefined', () => {
  const data = baseTableData({costBand: null, location: {geopoint: new GeoPoint(1, 2), venueNameSnapshot: null}});
  const doc = deriveTypesenseDocument('t1', data, NOW);

  assert.ok(doc);
  assert.equal(doc!.costBand, '');
  assert.equal(doc!.venueNameSnapshot, '');
});
