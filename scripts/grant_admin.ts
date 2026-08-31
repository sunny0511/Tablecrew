/**
 * scripts/grant_admin.ts
 *
 * Grants (or revokes) the `admin` Firebase Auth custom claim that
 * `reviewIdentityVerification` checks (functions/src/identity/index.ts,
 * docs/API_SPEC.md §3.7, ADR 0007).
 *
 * This exists because manual Tier 2 verification needs at least one human
 * who can approve submissions, and nothing in the app can grant that
 * authority — deliberately. The claim lives in Firebase Auth, not
 * Firestore, precisely so no application code path (and no compromised
 * client write) can hand out review authority; the only way in is an
 * Admin SDK call from a machine holding project credentials, which is what
 * this script is.
 *
 * SAFETY, following scripts/seed_staging.ts's conventions: it refuses any
 * project outside the three known TableCrew projects, requires an explicit
 * --yes, prints the resolved account for confirmation before writing, and
 * always shows the resulting claim set afterward. Granting on
 * tablecrew-prod additionally requires --i-understand-this-is-production,
 * because an admin claim there can approve real people's real government
 * IDs.
 *
 * Usage (after `npm install` in this directory, with
 * `gcloud auth application-default login` or GOOGLE_APPLICATION_CREDENTIALS
 * configured for the target project):
 *
 *   npm run grant:admin -- --project=tablecrew-dev --phone=+919876543210 --yes
 *   npm run grant:admin -- --project=tablecrew-dev --uid=abc123 --yes
 *   npm run grant:admin -- --project=tablecrew-dev --uid=abc123 --revoke --yes
 *
 * The claim only appears in an ID token after that account's next sign-in
 * or token refresh (Firebase refreshes roughly hourly). Signing out and
 * back in on the device is the fastest way to pick it up — until then the
 * account still gets ADMIN_ONLY, which is correct behavior, not a bug.
 */

import * as admin from 'firebase-admin';

const KNOWN_PROJECTS = ['tablecrew-dev', 'tablecrew-staging', 'tablecrew-prod'];

interface Args {
  project: string;
  uid?: string;
  phone?: string;
  revoke: boolean;
  yes: boolean;
  productionAcknowledged: boolean;
}

function parseArgs(argv: string[]): Args {
  const get = (name: string): string | undefined => {
    const hit = argv.find((a) => a.startsWith(`--${name}=`));
    return hit ? hit.slice(name.length + 3) : undefined;
  };
  return {
    project: get('project') ?? '',
    uid: get('uid'),
    phone: get('phone'),
    revoke: argv.includes('--revoke'),
    yes: argv.includes('--yes'),
    productionAcknowledged: argv.includes('--i-understand-this-is-production'),
  };
}

function fail(message: string): never {
  console.error(`\n  ✗ ${message}\n`);
  process.exit(1);
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  if (!KNOWN_PROJECTS.includes(args.project)) {
    fail(
        `--project must be one of ${KNOWN_PROJECTS.join(', ')} ` +
      `(got ${args.project || '<missing>'}).`,
    );
  }
  if (!args.uid && !args.phone) {
    fail('Pass either --uid=<firebase-auth-uid> or --phone=<E.164 phone number>.');
  }
  if (args.uid && args.phone) {
    fail('Pass --uid or --phone, not both.');
  }
  if (!args.yes) {
    fail('Refusing to run without --yes. Re-run with --yes once the command looks right.');
  }
  if (args.project === 'tablecrew-prod' && !args.productionAcknowledged) {
    fail(
        'Refusing to modify tablecrew-prod without ' +
      '--i-understand-this-is-production. An admin claim there can approve ' +
      "real people's real government IDs.",
    );
  }

  admin.initializeApp({projectId: args.project});
  const auth = admin.auth();

  const user = args.uid ?
    await auth.getUser(args.uid).catch(() => fail(`No account with uid ${args.uid}.`)) :
    await auth.getUserByPhoneNumber(args.phone!).catch(
        () => fail(`No account with phone number ${args.phone}.`),
    );

  console.log(`\n  Project : ${args.project}`);
  console.log(`  Account : ${user.uid}`);
  console.log(`  Phone   : ${user.phoneNumber ?? '(none)'}`);
  console.log(`  Current : ${JSON.stringify(user.customClaims ?? {})}`);
  console.log(`  Action  : ${args.revoke ? 'REVOKE admin' : 'GRANT admin'}\n`);

  // Merge rather than replace: blowing away unrelated claims that some
  // future feature may set would be a silent, hard-to-trace regression.
  const existing = user.customClaims ?? {};
  const next: Record<string, unknown> = {...existing};
  if (args.revoke) {
    delete next.admin;
  } else {
    next.admin = true;
  }

  await auth.setCustomUserClaims(user.uid, next);

  const updated = await auth.getUser(user.uid);
  console.log(`  ✓ Claims now: ${JSON.stringify(updated.customClaims ?? {})}`);
  console.log(
      '\n  The claim reaches an ID token only after that account\'s next ' +
    'sign-in or token refresh.\n  Sign out and back in on the device to pick ' +
    'it up immediately.\n',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
