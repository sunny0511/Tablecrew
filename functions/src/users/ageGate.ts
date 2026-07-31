/**
 * Pure age-gate logic backing `validateAge`/`completeAccountSetup`
 * (docs/API_SPEC.md §3.9) — the actual server-side 18+ enforcement point
 * docs/SECURITY.md's "Age Gating and Minimum Age Enforcement" describes.
 * Kept dependency-free and framework-free (no firebase-admin/-functions
 * imports) so it's unit-testable without the emulator, per docs/TESTING.md:
 * "Cloud Functions business logic... tested with a standard Node test
 * runner against faked Firestore/Auth inputs where the logic doesn't need
 * the emulator."
 */

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const MINIMUM_AGE_YEARS = 18;

/**
 * Returns true iff `value` is a well-formed ISO 8601 date string
 * ("YYYY-MM-DD") representing a real calendar date (rejecting e.g.
 * "2023-02-30") that is not in the future relative to `now`.
 */
export function isWellFormedDateOfBirth(
    value: unknown,
    now: Date = new Date(),
): value is string {
  if (typeof value !== 'string' || !ISO_DATE_PATTERN.test(value)) return false;

  const [yearStr, monthStr, dayStr] = value.split('-');
  const year = Number(yearStr);
  const month = Number(monthStr);
  const day = Number(dayStr);

  const parsed = new Date(Date.UTC(year, month - 1, day));
  // Reject dates that don't round-trip through the Date constructor (e.g.
  // "2023-02-30" silently rolls over to March 2nd).
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return false;
  }

  const nowUtcMidnight = Date.UTC(
      now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),
  );
  return parsed.getTime() <= nowUtcMidnight;
}

/**
 * Computes age in whole years as of `now`, given a well-formed
 * "YYYY-MM-DD" date of birth. Callers must validate with
 * `isWellFormedDateOfBirth` first — this function assumes a valid input
 * and does not re-validate the format.
 */
export function computeAgeAsOf(dateOfBirth: string, now: Date = new Date()): number {
  const [yearStr, monthStr, dayStr] = dateOfBirth.split('-');
  const birthYear = Number(yearStr);
  const birthMonth = Number(monthStr) - 1; // 0-indexed, matching Date#getUTCMonth
  const birthDay = Number(dayStr);

  let age = now.getUTCFullYear() - birthYear;
  const hasHadBirthdayThisYear =
    now.getUTCMonth() > birthMonth ||
    (now.getUTCMonth() === birthMonth && now.getUTCDate() >= birthDay);
  if (!hasHadBirthdayThisYear) {
    age -= 1;
  }
  return age;
}

/**
 * The actual 18+ enforcement check. Server-validated against the server's
 * own clock — never the client's, per docs/SECURITY.md: "not solely a
 * client-side gate, since client clocks/logic can be manipulated."
 */
export function isEligibleAge(dateOfBirth: string, now: Date = new Date()): boolean {
  return computeAgeAsOf(dateOfBirth, now) >= MINIMUM_AGE_YEARS;
}
