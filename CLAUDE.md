# CLAUDE.md

Guidance for Claude (or any AI coding agent) working in this repository.

## What this repository currently is

This repository is TableCrew's company knowledge base: complete product, engineering, design, and go-to-market documentation. As of this writing, **it contains no application code**, and that is intentional, not an oversight. Do not scaffold a Flutter project, do not generate Firebase configuration, and do not write application code in this repository unless a human founder or engineering lead has explicitly instructed you to begin implementation in that specific conversation. If a request is ambiguous about whether it wants documentation or code, default to documentation and ask.

## How to work in `docs/`

Before editing any document, read `docs/PRODUCT.md` first — it is the canonical, single-page source of truth for what TableCrew is, and every other document is expected to be consistent with it. If you find a contradiction between `docs/PRODUCT.md` and any other document, `docs/PRODUCT.md` wins unless a change has been deliberately made and logged in `CHANGELOG.md`.

When you edit a document that other documents reference (via backtick filenames, e.g. `` `docs/ARCHITECTURE.md` ``), check whether your edit invalidates a claim made elsewhere and fix it in the same pass. This codebase treats cross-document consistency as a correctness property, the same way a compiler treats type consistency — a documentation change that breaks a cross-reference is a bug.

Every document in `docs/` follows the same standard: no placeholders, no "TBD," no "coming soon." If a decision hasn't been made yet, either make a reasoned recommendation and justify it, or explicitly say the decision is open and state what would need to be true to resolve it — never leave a silent gap.

## Once application code begins

When implementation starts, this repository is expected to grow a standard Flutter app structure (`lib/`, `test/`, `ios/`, `android/`) alongside a `functions/` directory for Cloud Functions, per `docs/ARCHITECTURE.md` and `docs/ENGINEERING_GUIDELINES.md`. At that point:

- Follow `docs/ENGINEERING_GUIDELINES.md` for code style, state management (Riverpod), branching strategy, and PR conventions.
- Follow `docs/DATABASE.md` for all Firestore schema and security rules work — do not invent new collections or fields without updating that document in the same change.
- Follow `docs/API_SPEC.md` for the shape of any Cloud Function you add or modify.
- Follow `docs/SECURITY.md`'s safety-gate checklist before shipping anything that touches Discover, identity verification, or user-to-user contact.
- Follow `docs/TESTING.md`'s pyramid — new logic needs unit tests, new UI needs widget tests, and changes to Firestore rules need rules-emulator tests, before a PR is considered done.
- Follow `docs/DEPLOYMENT.md` and `docs/CI_CD.md` for how a change actually ships, including feature-flag and rollback expectations.

Code changes should keep the relevant documentation in sync in the same PR — a schema change lands with an updated `docs/DATABASE.md`, a new endpoint lands with an updated `docs/API_SPEC.md`, and so on. Documentation drift is treated as a bug, not cleanup for later.

## Values that constrain how you work here, not just what you build

`docs/VALUES.md` is not aspirational marketing copy; it is meant to change real decisions, including yours. In practice that means: prefer the option that respects user privacy and consent even when a more data-hungry option would perform better (see "Respect data like it's someone's actual life"); do not propose growth or engagement mechanics that rely on manufactured urgency, guilt, or dark patterns (see "Real connection over engagement metrics" and `docs/COPY_GUIDELINES.md`); and treat anything touching Discover, identity, or reporting/blocking as safety-gated work that should be flagged for explicit human review rather than shipped autonomously (see "Safety is a feature, not a department").

## Where to look before asking

- Product questions ("what is a Table," "what's in v1") → `docs/PRODUCT.md`, `docs/PRD.md`, `docs/FEATURES.md`
- Who we're building for → `docs/USER_PERSONAS.md`, `docs/USER_RESEARCH.md`
- Technical architecture questions → `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/API_SPEC.md`, `docs/FIREBASE.md`
- "How do I..." process questions → `docs/ENGINEERING_GUIDELINES.md`, `docs/TESTING.md`, `docs/DEPLOYMENT.md`, `docs/CI_CD.md`
- Visual, voice, or copy questions → `docs/DESIGN_SYSTEM.md`, `docs/BRAND_GUIDELINES.md`, `docs/COPY_GUIDELINES.md`
- What's being worked on right now → `TASKS.md`
- Why a past decision was made → `CHANGELOG.md`
