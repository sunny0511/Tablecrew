# 0007: Tier 2 identity verification — manual human review for Phase 0

**Status:** Accepted (2026-08, Milestone F7). **Supersedes [0005](0005-persona-over-stripe-identity.md)** for the Phase 0 window. Explicitly interim: this ADR expects to be superseded in turn by a vendor ADR once a KYC vendor is contracted, and is written to make that replacement cheap.

## Context

Milestone F7 (Discover) has been blocked on a Tier 2 identity-verification vendor since 2026-08-02 — roughly four weeks of no progress on the milestone's largest remaining piece. The state of that decision, per `TASKS.md`:

- **Persona** (the ADR 0005 choice): founder reached out directly; no response.
- **Surepass**: identified as an India-specific alternative, not yet evaluated in depth.
- **Socure**: evaluated and parked — no evidence of UIDAI-backed Aadhaar verification, and a backend-initiated/webhook-driven flow that would require rewriting `docs/API_SPEC.md` §3.7 rather than swapping a vendor name.

Underneath all three sits a regulatory fact surfaced during that research and recorded in `TASKS.md`: live Aadhaar e-KYC requires UIDAI-licensed AUA/KUA status, restricted to regulated entities and their approved partners. TableCrew cannot hold that status itself. So "does this vendor support Aadhaar" is not a feature-matrix question with a quick answer — it is a question about the vendor's own licensing posture, and it is the question that has kept this decision open.

Meanwhile every vendor-independent piece of F7 is done (`requestSeat`'s blocked-user check, the Table→Typesense sync trigger with real local/CI emulation). What remains — Tier 2 verification, Screen 8's real interstitial, and the Discover screens that sit behind the Tier 2 gate — is blocked entirely on a decision with no forcing function and no deadline.

Founder direction, 2026-08: unblock it with a manual, human-reviewed verification flow, and let the vendor decision resolve on its own timeline rather than continuing to gate engineering on it.

## Decision

For Phase 0, Tier 2 identity verification is performed by **manual human review**, with no third-party identity vendor in the flow at all.

- The user uploads a government ID image and a selfie to a Cloud Storage path that is **owner-write-only and readable by no client at all** — stricter than the profile-photo path built in Milestone F5, which permits owner reads.
- `submitIdentityVerification` records a pending submission. No client ever supplies a pass/fail signal, exactly as under ADR 0005.
- The founder reviews submissions through the Firebase console (Firestore for the queue, Cloud Storage for the images) and calls an **admin-only** `reviewIdentityVerification` to approve or reject. Admin authority is a Firebase Auth custom claim, checked server-side; there is no admin UI, which is appropriate at beta volume and consistent with an organization admin console being Phase 4 scope per `docs/ROADMAP.md`.
- The client learns the outcome from a live Firestore listener on its own submission document — the same proven shape as the photo-moderation verdict built in Milestone F5. **No email is sent, and no email address is collected.**
- On any decision, approve or reject, the uploaded images are **deleted immediately**. Only the decision record survives.

Notably, no email is involved anywhere. The founder's original framing was an emailed request for the user to send their ID; that was dropped once two facts surfaced: TableCrew collects no email address from anyone (onboarding is phone-only; `email` is documented as "optional, if linked via Apple/Google" and `completeAccountSetup` hardcodes it to `null`), and no email vendor has ever been chosen in this codebase. Routing government IDs through email would also have put them in a mailbox indefinitely — strictly worse than the Storage path under both `docs/SECURITY.md` and India's DPDP Act.

## Consequences

**Makes easier.** F7 unblocks immediately, with no vendor, contract, billing relationship, or new client SDK. The upload path reuses the Storage-rules-plus-trigger shape Milestone F5 already built and verified. The Discover screens behind the Tier 2 gate become buildable now rather than whenever a vendor conversation concludes.

**Makes harder — five real consequences, none of them cosmetic:**

1. **This reverses a security property `docs/SECURITY.md` currently states as fact.** That document says ID images and biometric data "never touch Firestore or the client — they live in Persona's vault, referenced by an opaque case ID." Under this ADR, TableCrew itself is the custodian of government ID images, which makes it the data fiduciary for that data under the DPDP Act and materially raises the stakes of any Storage misconfiguration. Mitigated, not eliminated, by three things: rules that permit no client read at all, deletion of the images on decision, and a decision record that holds no ID-derived content. `docs/SECURITY.md` is corrected in the same pass rather than left contradicting the implementation.

2. **Liveness is materially weaker, and copy must not pretend otherwise.** A selfie holding an ID does not defeat a photo-of-a-photo, a printed image, or a video replay — which is precisely what vendor liveness checks exist to defeat. Tier 2's own definition in `docs/SECURITY.md` ("confirms the person holding the phone matches the ID and is physically present, not a photo of a photo") is not fully met by this mechanism. The `id_verified` badge means less during Phase 0 than that sentence promises, and this ADR records that plainly rather than letting the badge silently overstate itself.

3. **Ban-evasion duplicate detection is lost entirely.** `docs/SECURITY.md` names Persona's cross-account document/biometric duplicate detection as the concrete mechanism behind `docs/DATABASE.md` §7's commitment to prevent a banned user re-registering. Manual review has no cross-account matching, and a human reviewer's memory is not a control. This is the most consequential capability gap of the three, because it is a named commitment elsewhere in the knowledge base that this decision silently breaks if not disclosed.

4. **The ID/DOB cross-check becomes a human step.** `docs/SECURITY.md` requires the ID-derived date of birth to be cross-checked against the self-reported DOB before granting the tier. No OCR runs here, so that check now depends on the reviewer performing it. The review callable requires an explicit reviewer attestation rather than assuming it happened.

5. **It does not scale, by construction.** Manual review is fine at closed-beta volume and breaks well before `docs/MARKETING.md`'s Discover liquidity thresholds (15–20 weekly Open Tables and 25+ rated hosts per city). This is a bridge to a vendor, not a destination.

**Reversibility, deliberately designed in.** The client contract (`submitIdentityVerification` plus a status listener) and the tier-granting logic are the same shape a vendor integration needs. A future vendor ADR replaces what happens *between* submission and decision — a webhook or a server-side inquiry fetch instead of a human — without touching the client, the Storage path, or the code that writes `verification.verificationTier`. Socure's webhook-driven model, the one architecture that would have forced a client rewrite under ADR 0005's contract, fits this shape without one.

## Alternatives Considered

- **Keep waiting on Persona.** Rejected. Four weeks produced no response, and there is no deadline that would end the wait. This ADR does not close the vendor question — Persona and Surepass both remain live options, tracked in `TASKS.md` — it just stops F7 from being hostage to it.
- **Contract Surepass now instead.** Not rejected on the merits; Surepass remains the most likely successor to this ADR, since Aadhaar Offline e-KYC/XML/QR verification needs no AUA/KUA status and is a genuinely available path. But it is still a vendor decision with an integration behind it, and the founder's direction was to unblock immediately rather than trade one vendor wait for another.
- **Email the ID as an attachment.** Rejected — the founder's original framing, dropped for the reasons in the Decision section: no email address is collected anywhere, no email vendor exists, and IDs would sit unencrypted in a mailbox indefinitely with no liveness signal at all. Strictly worse than the in-app path on every axis including build cost.
- **Skip Tier 2 for Phase 0 and let Discover launch on phone verification alone.** Rejected outright. It contradicts `docs/VALUES.md`'s "Safety is a feature, not a department" and `docs/ROADMAP.md`'s entire Crew-first-before-Discover sequencing rationale, which exists precisely so strangers are not introduced in person without a verified-identity gate. A weaker Tier 2 with disclosed limits is a different thing from no Tier 2.
