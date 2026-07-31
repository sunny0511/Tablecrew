/**
 * Pure field-validation helpers backing `completeAccountSetup`
 * (docs/API_SPEC.md §3.9), mirroring docs/SCREEN_SPECIFICATIONS.md
 * Screens 5-6's client-side validation rules server-side. Per
 * docs/SECURITY.md, client-side validation is never treated as a security
 * boundary on its own — every rule enforced in the Flutter UI is
 * re-enforced here.
 */

const DISPLAY_NAME_MAX_LENGTH = 30;
const BIO_MAX_LENGTH = 140;
const MIN_INTEREST_TAGS = 3;

/** docs/SCREEN_SPECIFICATIONS.md Screen 5: "First name required, 1-30 characters." */
export function isValidDisplayName(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  return trimmed.length >= 1 && value.length <= DISPLAY_NAME_MAX_LENGTH;
}

/** docs/SCREEN_SPECIFICATIONS.md Screen 5: "140-character bio text area (optional)." */
export function isValidBio(value: unknown): value is string | null | undefined {
  if (value === null || value === undefined) return true;
  return typeof value === 'string' && value.length <= BIO_MAX_LENGTH;
}

/** docs/SCREEN_SPECIFICATIONS.md Screen 6: "Minimum 3 interests required." */
export function isValidInterestTags(value: unknown): value is string[] {
  return (
    Array.isArray(value) &&
    value.length >= MIN_INTEREST_TAGS &&
    value.every((tag) => typeof tag === 'string' && tag.length > 0)
  );
}

// Deliberately permissive (not a full BCP-47 validator) since locale
// correctness isn't a safety boundary the way DOB/age is — this just
// rejects an obviously malformed or empty value, e.g. an accidental empty
// string reaching the server.
const LOCALE_PATTERN = /^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$/;

export function isValidLocale(value: unknown): value is string {
  return typeof value === 'string' && LOCALE_PATTERN.test(value);
}
