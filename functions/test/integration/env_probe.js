/*
 * Throwaway diagnostic for the Milestone F7 UPLOAD_NOT_FOUND failure.
 * Plain JS on purpose: no TypeScript build, no test runner, nothing that
 * can swallow stdout. Delete once the integration suite is green.
 *
 * Run from the repo root:
 *   firebase emulators:exec --only auth,firestore,functions,storage \
 *     --project tablecrew-dev "node functions/test/integration/env_probe.js"
 */
const {initializeApp} = require('firebase-admin/app');
const {getStorage} = require('firebase-admin/storage');

const log = (...a) => process.stderr.write(a.join(' ') + '\n');

log('\n================ PROBE ================');
log('GCLOUD_PROJECT               :', process.env.GCLOUD_PROJECT || '(unset)');
log('FIREBASE_STORAGE_EMULATOR_HOST:',
    process.env.FIREBASE_STORAGE_EMULATOR_HOST || '(UNSET -> real GCS)');
log('FIRESTORE_EMULATOR_HOST      :', process.env.FIRESTORE_EMULATOR_HOST || '(unset)');
log('FIREBASE_CONFIG              :', process.env.FIREBASE_CONFIG || '(unset)');

let configBucket = '(none)';
try {
  configBucket = JSON.parse(process.env.FIREBASE_CONFIG || '{}').storageBucket || '(none)';
} catch (e) {
  configBucket = '(FIREBASE_CONFIG unparseable)';
}
log('storageBucket from config    :', configBucket);

(async () => {
  const projectId = process.env.GCLOUD_PROJECT || 'tablecrew-dev';
  for (const candidate of [configBucket, `${projectId}.firebasestorage.app`,
    `${projectId}.appspot.com`]) {
    if (!candidate || candidate.startsWith('(')) continue;
    try {
      const app = initializeApp({projectId, storageBucket: candidate},
          `probe-${candidate}`);
      const file = getStorage(app).bucket(candidate)
          .file('identity-verifications/probe-uid/probe-file');
      await file.save(Buffer.from('probe'), {contentType: 'image/jpeg'});
      const [exists] = await file.exists();
      log(`WRITE+READBACK ${candidate}: ${exists ? 'OK' : 'WROTE BUT NOT READABLE'}`);
      await file.delete().catch(() => {});
    } catch (err) {
      log(`WRITE+READBACK ${candidate}: FAILED -> ${err.message.split('\n')[0]}`);
    }
  }
  log('=======================================\n');
})();
