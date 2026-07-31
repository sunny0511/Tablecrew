# scripts/

One-off ops scripts, data migrations, and seed scripts, per `docs/ENGINEERING_GUIDELINES.md`'s repository structure.

Two scripts are referenced elsewhere in this knowledge base but don't exist yet — they're expected first work, not something a founding engineer should go looking for and fail to find:

- **`seed_staging.ts`** (referenced by `docs/TESTING.md`'s "Test Data Management" section) — seeds the staging environment with synthetic fixture data. Lands in Milestone F1 alongside the core data layer, once there's a real schema to seed.
- **`cut_release.sh`** (referenced by `docs/CI_CD.md`'s release-tag section) — tags a verified `main` commit as a release, triggering the mobile release pipeline (stage 7). Not needed until there's a mobile build worth releasing, well after Foundation.
