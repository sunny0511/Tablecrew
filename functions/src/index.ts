/**
 * Cloud Functions entry point.
 *
 * Per docs/ENGINEERING_GUIDELINES.md, this file only re-exports functions
 * defined in the domain directories below (tables/, crews/, discover/,
 * trust/, triggers/) — it should never contain function *logic* itself.
 *
 * Scaffold note (Milestone F0): no real endpoints exist yet. The domain
 * directories are stubbed out so the directory shape matches
 * docs/ENGINEERING_GUIDELINES.md and docs/DATABASE.md's collection layout
 * from day one. `healthCheck` below exists only to prove the
 * firebase-functions/firebase-admin toolchain builds and deploys end to end;
 * it is expected to be deleted once the first real endpoint from
 * docs/API_SPEC.md (createTable, per Milestone F4) lands.
 */

import * as admin from 'firebase-admin';
import {onRequest} from 'firebase-functions/v2/https';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export * from './tables';
export * from './crews';
export * from './discover';
export * from './trust';
export * from './shared';
export * from './triggers';

/**
 * Temporary scaffold-verification endpoint. Delete once the first real
 * endpoint from docs/API_SPEC.md lands (Milestone F4).
 */
export const healthCheck = onRequest((req, res) => {
  res.status(200).json({status: 'ok', service: 'tablecrew-functions'});
});
