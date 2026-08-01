/**
 * Photo-moderation domain: the Storage-triggered Cloud Function backing
 * docs/FIREBASE.md §2.5's moderation hooks (ADR 0006, docs/DATABASE.md
 * §3.1a). Added Milestone F5, alongside `completeAccountSetup`'s
 * `photoUploadId`/`PHOTO_NOT_APPROVED` contract (docs/API_SPEC.md §3.9) —
 * see CHANGELOG.md's "F5 kickoff" entry for the three-document
 * contradiction (FIREBASE.md vs. API_SPEC.md vs. DATABASE.md) this closes.
 *
 * Disclosed, real limitation: this has not yet been exercised against a
 * live Cloud Vision API call anywhere (no GCP credentials with Vision API
 * enabled have been available in any environment that's built this
 * codebase so far). The `@google-cloud/vision` client's
 * `safeSearchDetection` response shape is coded against its documented
 * TypeScript types, but — the same caveat this codebase has already
 * disclosed for other real-vendor integrations (Persona/Aadhaar coverage,
 * ADR 0005) — the first real call against a live project is what actually
 * confirms this, not a read of the SDK's type definitions alone. Tracked in
 * TASKS.md as an open verification item, not silently assumed correct.
 */

import {randomUUID} from 'node:crypto';
import {ImageAnnotatorClient} from '@google-cloud/vision';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onObjectFinalized} from 'firebase-functions/v2/storage';
import {
  approvedObjectPath,
  classifySafeSearchVerdict,
  parsePendingProfilePhotoPath,
  type SafeSearchLikelihood,
} from './moderation';

let visionClient: ImageAnnotatorClient | undefined;

/** Lazily constructed so importing this module never requires GCP
 * credentials to exist (e.g. under `tsc --noEmit`/unit tests, which never
 * call this function's handler body at all). */
function getVisionClient(): ImageAnnotatorClient {
  if (!visionClient) {
    visionClient = new ImageAnnotatorClient();
  }
  return visionClient;
}

/** Cloud Vision's client returns SafeSearch likelihoods as the enum's
 * string name (e.g. `'VERY_LIKELY'`) for this convenience method, per its
 * documented TypeScript types — this narrows the client's broader
 * `string | null | undefined` typing down to the enum this pipeline's
 * policy function expects, defaulting anything unrecognized to `'UNKNOWN'`
 * rather than throwing, since a moderation pipeline should fail toward
 * "flag nothing new, log it" on an unexpected shape, not crash the trigger. */
function toLikelihood(value: string | null | undefined): SafeSearchLikelihood {
  const known: readonly SafeSearchLikelihood[] = [
    'UNKNOWN', 'VERY_UNLIKELY', 'UNLIKELY', 'POSSIBLE', 'LIKELY', 'VERY_LIKELY',
  ];
  return (known as readonly string[]).includes(value ?? '') ?
    (value as SafeSearchLikelihood) :
    'UNKNOWN';
}

export const moderateUploadedPhoto = onObjectFinalized(
    {},
    async (event) => {
      const filePath = event.data.name;
      const bucketName = event.data.bucket;
      const parsed = parsePendingProfilePhotoPath(filePath);
      if (!parsed) {
        // Not a path this pipeline owns — most importantly, this excludes
        // its own approved/ copies below, which would otherwise re-trigger
        // this same function in a loop.
        return;
      }
      const {userId, uploadId} = parsed;

      const bucket = getStorage().bucket(bucketName);
      const pendingFile = bucket.file(filePath);
      const db = getFirestore();
      const moderationRef = db.doc(`users/${userId}/private/photoModeration/${uploadId}`);

      // Record the attempt as "pending" immediately, before the
      // (network-bound) Vision call — so a client listening on this
      // document from the moment it starts the upload always finds a
      // document to read, rather than racing a nonexistent-document read
      // against the Vision call's own latency (docs/SCREEN_SPECIFICATIONS.md
      // Screen 5's "Reviewing your photo..." loading state depends on this).
      await moderationRef.set({
        status: 'pending',
        approvedUrl: null,
        flagReason: null,
        storagePath: filePath,
        createdAt: FieldValue.serverTimestamp(),
      });

      const [result] = await getVisionClient().safeSearchDetection(
          `gs://${bucketName}/${filePath}`,
      );
      const annotation = result.safeSearchAnnotation ?? {};
      const verdict = classifySafeSearchVerdict({
        adult: toLikelihood(annotation.adult as string | null | undefined),
        violence: toLikelihood(annotation.violence as string | null | undefined),
        racy: toLikelihood(annotation.racy as string | null | undefined),
        medical: toLikelihood(annotation.medical as string | null | undefined),
        spoof: toLikelihood(annotation.spoof as string | null | undefined),
      });

      if (verdict.status === 'flagged') {
        await moderationRef.set(
            {status: 'flagged', flagReason: verdict.flagReason},
            {merge: true},
        );

        // Trust & Safety review task, per docs/DATABASE.md §3.6's Reports
        // model — a moderation flag on media is its own report-like
        // signal, not a silent client-side rejection (docs/FIREBASE.md
        // §2.5, docs/SECURITY.md's corrected Content Moderation section).
        // reasonCode: 'flagged_media' and reporterId: 'system:photo-
        // moderation' are the two additions docs/DATABASE.md §3.6 made
        // this milestone specifically for automated-flag reports, which
        // have no human reporter.
        await db.collection('reports').add({
          reporterId: 'system:photo-moderation',
          targetType: 'user',
          targetId: userId,
          reasonCode: 'flagged_media',
          severity: null,
          isDuressSignal: false,
          details: `Automated SafeSearch flag on profile photo upload ` +
            `${uploadId}: ${verdict.flagReason}`,
          status: 'open',
          assignedTo: null,
          resolutionNotes: null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      // Clean verdict: copy to the public approved/ path (also what the
      // Resize Images Extension watches, docs/FIREBASE.md §2.5) and mint a
      // standard Firebase Storage download-URL token — the same mechanism
      // the client SDKs' own getDownloadURL() uses, so approvedUrl is a
      // normal, directly-usable download link rather than a signed URL
      // with an expiry someone has to remember to manage.
      const approvedPath = approvedObjectPath(userId, uploadId);
      const approvedFile = bucket.file(approvedPath);
      await pendingFile.copy(approvedFile);

      const downloadToken = randomUUID();
      await approvedFile.setMetadata({
        metadata: {firebaseStorageDownloadTokens: downloadToken},
      });
      const approvedUrl = 'https://firebasestorage.googleapis.com/v0/b/' +
        `${bucketName}/o/${encodeURIComponent(approvedPath)}` +
        `?alt=media&token=${downloadToken}`;

      await moderationRef.set(
          {status: 'approved', approvedUrl},
          {merge: true},
      );
    },
);

export {approvedObjectPath, classifySafeSearchVerdict, parsePendingProfilePhotoPath} from './moderation';
