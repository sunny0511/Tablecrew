# 0006: Photo moderation vendor — Google Cloud Vision SafeSearch over AWS Rekognition / a dedicated moderation vendor

**Status:** Accepted (2026-08, Milestone F5)

## Context

`docs/FIREBASE.md` §2.5 has, since the F0-era documentation pass, described a Cloud Storage-triggered Cloud Function that runs every profile/Table photo upload through "an automated content-moderation check (an image-safety classification API call)" before the corresponding Firestore `photoUrl` field is allowed to reference it — flagged images are quarantined and generate a Trust & Safety review task. That description never named a specific vendor, and no milestone's scope ever scheduled actually building the Function, so the decision stayed unmade until Milestone F5 (Screen 5, Profile Setup) became the first real caller of it — this ADR is written at decision time, not backfilled, per `docs/adr/README.md`'s stated going-forward practice.

Requirements: (1) fast enough that Profile Setup's "Continue" button isn't blocked for an unreasonable wait (Screen 5's UX already blocks on upload confirmation; adding a moderation-verdict wait on top of that needs the check itself to resolve in low single-digit seconds, not an async human-review queue); (2) minimal new operational surface, given this is a single-founder-plus-AI-agent engineering team at this stage, not a team that benefits from managing a fourth or fifth vendor relationship; (3) must integrate cleanly with a Cloud Storage-triggered Cloud Function (Gen 2), the mechanism `docs/FIREBASE.md` already committed to.

## Decision

Use **Google Cloud Vision API's SafeSearch Detection** feature, called synchronously from the Storage-triggered moderation Cloud Function on every upload under `users/{uid}/profile/*` and `tables/{tableId}/photos/*`.

## Consequences

**Makes easier:** zero new vendor relationship, IAM setup, or billing account — Cloud Vision is a GCP API, and this project already runs entirely on GCP/Firebase (`docs/FIREBASE.md` §1); authentication is the same service-account credential Cloud Functions already runs under, no separate API-key/secret-management story the way Stripe's or Persona's keys need Secret Manager bindings (`docs/FIREBASE.md` §2.10). SafeSearch Detection returns adult/violence/racy/medical/spoof likelihood scores in a single synchronous API call (typically well under 1 second for a single image), which is fast enough to sit inline in the upload→moderate→confirm path Screen 5's "Continue" button waits on (see `docs/SCREEN_SPECIFICATIONS.md` Screen 5's updated Loading States, this same milestone). It's also the exact reference architecture Google's own Firebase documentation demonstrates for "moderate images on upload," so the Storage-trigger-plus-Vision-API pattern this Function implements is a well-trodden path, not a novel integration.

**Makes harder — disclosed, not silently accepted:** SafeSearch's five categories (adult, violence, racy, medical, spoof) cover the specific, bounded threat model TableCrew's profile/Table photos actually present — this is not general-purpose trust-and-safety content moderation (no hate-symbol detection, no OCR-based text-in-image policy scanning, no context-aware harassment detection). If abuse patterns emerge that SafeSearch's categories don't catch (e.g., a photo that's technically SFW by SafeSearch's categories but is impersonation, a screenshot/non-human image already flagged softly at the UI layer per Screen 5's client-side nudge, or otherwise policy-violating in a way outside SafeSearch's five categories), this is a real coverage gap, not something this decision claims to solve. Revisit with a dedicated moderation vendor (Sightengine, Hive) if that gap proves material once Discover's photo volume is real — tracked as a future revisit trigger, not an open item blocking F5.

## Alternatives Considered

- **AWS Rekognition (content moderation labels).** Comparable detection quality and also a single synchronous API call, but introduces a second cloud vendor (AWS IAM, a second set of credentials/billing) into a stack that is otherwise entirely GCP/Firebase-native, for no accuracy or cost advantage significant enough to justify that operational split at this stage.
- **A dedicated moderation vendor (Sightengine, Hive Moderation, similar).** These offer materially broader category coverage (weapons, drugs, text-in-image OCR moderation, custom policy models) and are worth a serious look once Discover's photo volume and abuse-pattern data actually justify the extra vendor relationship and its own cost/Secret-Manager-bound API key — but for Foundation-stage volume, adding a fourth vendor purely on the possibility of a coverage gap that hasn't yet materialized is premature, not conservative.
