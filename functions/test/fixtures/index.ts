/**
 * Shared fixtures library for Cloud Functions unit tests, per
 * docs/TESTING.md's "Test Data Management and Fixtures" section. Built in
 * Milestone F1 alongside the Firestore schema it mirrors
 * (docs/DATABASE.md §3.1/§3.2/§3.3/§3.4/§3.9); extend this library rather
 * than hand-rolling fixture objects inline as later milestones add
 * business-logic unit tests against these entities.
 */

export * from './users';
export * from './tables';
export * from './rsvps';
export * from './crews';
export * from './idempotencyKeys';
