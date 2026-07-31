# scripts/

One-off ops scripts, data migrations, and seed scripts, per `docs/ENGINEERING_GUIDELINES.md`'s repository structure. Its own small npm package (own `package.json`/`tsconfig.json`/`node_modules`), independent of `functions/` and `firestore/test/rules/`.

**`seed_staging.ts`** (referenced by `docs/TESTING.md`'s "Test Data Management" section) — landed in Milestone F1, alongside the core data layer it seeds. Populates the real `tablecrew-staging` Firebase project with a small, realistic, entirely synthetic set of Users/Crews/Tables, so staging is never empty and never contains real user data. Refuses to run against anything other than `tablecrew-staging` (never dev, never prod) and requires an explicit `--yes` flag — see the file's own top-of-file comment for the full safety rationale. Run via `npm run seed:staging -- --project=tablecrew-staging --yes` after `npm install` in this directory.

One script referenced elsewhere in this knowledge base doesn't exist yet:

- **`cut_release.sh`** (referenced by `docs/CI_CD.md`'s release-tag section) — tags a verified `main` commit as a release, triggering the mobile release pipeline (stage 7). Not needed until there's a mobile build worth releasing, well after Foundation.
