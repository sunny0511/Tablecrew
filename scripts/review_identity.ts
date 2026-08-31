/**
 * scripts/review_identity.ts
 *
 * The operator client for manual Tier 2 identity verification (ADR 0007,
 * docs/API_SPEC.md §3.7). Lists submissions awaiting review, and applies a
 * decision by calling `reviewIdentityVerification` — the real callable,
 * with all of its validation, never a direct Firestore write.
 *
 * That last point is the whole design of this script. It would be simpler
 * to have an Admin SDK script write `verification.verificationTier`
 * itself, and it would be wrong: the callable is where the reviewer's DOB
 * attestation is enforced, where the open-report re-check happens at apply
 * time, where the images get deleted, and where the audit record is
 * written. A second write path would drift from all four. So this script
 * authenticates as the admin user and goes through the front door.
 *
 * Usage:
 *
 *   npm run review -- --project=tablecrew-dev --list
 *
 *   npm run review -- --project=tablecrew-dev --submission=<id> \
 *     --approve --dob-matches
 *
 *   npm run review -- --project=tablecrew-dev --submission=<id> \
 *     --reject --reason="The ID photo is too blurry to read."
 *
 * Deciding (not listing) needs two extra values, by flag or environment:
 *   --admin-uid=  / TABLECREW_ADMIN_UID    the account holding the `admin`
 *                                          claim (see grant_admin.ts)
 *   --api-key=    / TABLECREW_WEB_API_KEY  the project's Web API key, from
 *                                          Firebase console > Project
 *                                          settings. Not a secret — it ships
 *                                          in every client app — it is just
 *                                          what exchanges a custom token for
 *                                          an ID token.
 *
 * Requires `gcloud auth application-default login` or
 * GOOGLE_APPLICATION_CREDENTIALS for the target project, same as
 * seed_staging.ts.
 */

import * as admin from 'firebase-admin';

const KNOWN_PROJECTS = ['tablecrew-dev', 'tablecrew-staging', 'tablecrew-prod'];
const REGION = 'us-central1';
const SIGNED_URL_TTL_MS = 15 * 60 * 1000;

function arg(name: string): string | undefined {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : undefined;
}
function flag(name: string): boolean {
  return process.argv.includes(`--${name}`);
}
function fail(message: string): never {
  console.error(`\n  ✗ ${message}\n`);
  process.exit(1);
}

async function listPending(
    db: admin.firestore.Firestore,
    bucketName: string,
): Promise<void> {
  const snap = await db.collection('identityVerifications')
      .where('status', '==', 'pending_review')
      .orderBy('createdAt', 'asc')
      .get();

  if (snap.empty) {
    console.log('\n  Nothing awaiting review.\n');
    return;
  }

  console.log(`\n  ${snap.size} submission(s) awaiting review:\n`);
  for (const doc of snap.docs) {
    const d = doc.data();
    console.log(`  ── ${doc.id}`);
    console.log(`     user         : ${d.userId}`);
    console.log(`     declared type: ${d.documentType}  (self-declared, verify by looking)`);
    console.log(`     submitted    : ${d.createdAt?.toDate?.()?.toISOString() ?? '(unknown)'}`);

    const profile = await db.doc(`users/${d.userId}/private/profile`).get();
    const dob = profile.data()?.dateOfBirth ?? '(none on file)';
    // Printed because the reviewer has to compare it against the document
    // before attesting --dob-matches. Making them go find it in another
    // console tab is how that check quietly stops happening.
    console.log(`     DOB on file  : ${dob}   <- compare against the ID`);

    for (const [label, path] of [
      ['ID   ', d.idDocumentPath],
      ['selfie', d.selfiePath],
    ] as Array<[string, string | null]>) {
      if (!path) {
        console.log(`     ${label}       : (already deleted)`);
        continue;
      }
      try {
        const [url] = await admin.storage().bucket(bucketName).file(path)
            .getSignedUrl({action: 'read', expires: Date.now() + SIGNED_URL_TTL_MS});
        console.log(`     ${label}       : ${url}`);
      } catch {
        // Signing needs a service-account key; user credentials from
        // `gcloud auth application-default login` cannot sign. Fall back to
        // the path so the reviewer can open it in the console rather than
        // being stuck.
        console.log(`     ${label}       : gs://${bucketName}/${path}`);
        console.log('              (could not sign a URL — open it in the Firebase console)');
      }
    }
    console.log('');
  }
  console.log('  Approve:  --submission=<id> --approve --dob-matches');
  console.log('  Reject :  --submission=<id> --reject --reason="..."\n');
}

async function decide(projectId: string): Promise<void> {
  const submissionId = arg('submission')!;
  const approve = flag('approve');
  const reject = flag('reject');
  if (approve === reject) {
    fail('Pass exactly one of --approve or --reject.');
  }

  const adminUid = arg('admin-uid') ?? process.env.TABLECREW_ADMIN_UID;
  const apiKey = arg('api-key') ?? process.env.TABLECREW_WEB_API_KEY;
  if (!adminUid) fail('Set --admin-uid= or TABLECREW_ADMIN_UID.');
  if (!apiKey) fail('Set --api-key= or TABLECREW_WEB_API_KEY.');

  const dobMatches = flag('dob-matches');
  const reason = arg('reason');
  if (approve && !dobMatches) {
    fail(
        'An approval requires --dob-matches: you are attesting that the date ' +
      'of birth on the ID matches the one on file. The server refuses an ' +
      'approval without it (docs/SECURITY.md age cross-check).',
    );
  }
  if (reject && !reason) {
    fail('A rejection requires --reason="..." — the user sees it and acts on it.');
  }

  // Sign in as the admin account so the callable sees a real ID token
  // carrying the `admin` claim. The claim itself is set separately by
  // grant_admin.ts; this only obtains a token for it.
  const customToken = await admin.auth().createCustomToken(adminUid);
  const signIn = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({token: customToken, returnSecureToken: true}),
      },
  );
  if (!signIn.ok) {
    fail(`Could not sign in as ${adminUid}: ${signIn.status} ${await signIn.text()}`);
  }
  const {idToken} = await signIn.json() as {idToken: string};

  const res = await fetch(
      `https://${REGION}-${projectId}.cloudfunctions.net/reviewIdentityVerification`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          data: {
            submissionId,
            decision: approve ? 'approve' : 'reject',
            dobMatchesId: dobMatches,
            ...(reason ? {rejectionReason: reason} : {}),
          },
        }),
      },
  );

  const body = await res.json() as {result?: unknown; error?: {message?: string}};
  if (!res.ok || body.error) {
    fail(`Review failed: ${res.status} ${JSON.stringify(body.error ?? body)}`);
  }
  console.log(`\n  ✓ ${JSON.stringify(body.result)}\n`);
}

async function main(): Promise<void> {
  const project = arg('project') ?? '';
  if (!KNOWN_PROJECTS.includes(project)) {
    fail(`--project must be one of ${KNOWN_PROJECTS.join(', ')} (got ${project || '<missing>'}).`);
  }
  const listing = flag('list');
  const submissionId = arg('submission');
  if (listing === Boolean(submissionId)) {
    fail('Pass either --list or --submission=<id>.');
  }

  admin.initializeApp({projectId: project});
  const bucketName = arg('bucket') ?? `${project}.firebasestorage.app`;

  if (listing) {
    await listPending(admin.firestore(), bucketName);
  } else {
    await decide(project);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
