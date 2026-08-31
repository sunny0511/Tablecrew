/**
 * Cloud Functions entry point.
 *
 * Per docs/ENGINEERING_GUIDELINES.md, this file only re-exports functions
 * defined in the domain directories below (tables/, crews/, discover/,
 * trust/, triggers/, users/, media/) — it should never contain function
 * *logic* itself.
 *
 * Scaffold note (Milestone F0): no real endpoints exist yet. The domain
 * directories are stubbed out so the directory shape matches
 * docs/ENGINEERING_GUIDELINES.md and docs/DATABASE.md's collection layout
 * from day one. `healthCheck` below exists only to prove the
 * firebase-functions/firebase-admin toolchain builds and deploys end to end;
 * it is expected to be deleted once the first real endpoint from
 * docs/API_SPEC.md (createTable, per Milestone F4) lands.
 *
 * Milestone F2 update: firebase-admin bumped 12.6.0 -> 14.2.0 (see
 * TASKS.md), which removes the old namespaced `admin.apps` /
 * `admin.initializeApp()` API entirely in favor of the modular
 * `firebase-admin/app` import — this is a real breaking change the bump
 * surfaced via a genuine `tsc` compile error, not a style preference.
 */

import {getApps, initializeApp} from 'firebase-admin/app';
import {onRequest} from 'firebase-functions/v2/https';

if (getApps().length === 0) {
  initializeApp();
}

export * from './tables';
export * from './crews';
export * from './discover';
export * from './trust';
export * from './shared';
export * from './triggers';
export * from './users';
export * from './media';
export * from './identity';

/**
 * Temporary scaffold-verification endpoint. Delete once the first real
 * endpoint from docs/API_SPEC.md lands (Milestone F4).
 */
export const healthCheck = onRequest((_req, res) => {
  res.status(200).json({status: 'ok', service: 'tablecrew-functions'});
});
