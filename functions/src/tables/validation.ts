/**
 * Pure field-validation helpers backing the Tables domain (docs/API_SPEC.md
 * §3.1), same hand-rolled-validator convention `functions/src/users/validation.ts`
 * established in Milestone F2 (see that file's own header, and
 * docs/API_SPEC.md's Milestone F4 correction note on `createTable` — this
 * codebase never adopted Zod despite an earlier draft of that spec line
 * saying otherwise).
 */

const TITLE_MIN_LENGTH = 1;
const TITLE_MAX_LENGTH = 100;
const DESCRIPTION_MAX_LENGTH = 1000;

/** docs/API_SPEC.md §3.1 `createTable`: "required, 1-100 chars." */
export function isValidTitle(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  return trimmed.length >= TITLE_MIN_LENGTH && value.length <= TITLE_MAX_LENGTH;
}

/** docs/API_SPEC.md §3.1 `createTable`: "optional, max 1000 chars." */
export function isValidDescription(value: unknown): value is string | null | undefined {
  if (value === null || value === undefined) return true;
  return typeof value === 'string' && value.length <= DESCRIPTION_MAX_LENGTH;
}

/**
 * docs/PRODUCT.md's activity-based recommended-size table is the only
 * place any interest-tag strings are actually named with product
 * reasoning behind them; docs/API_SPEC.md's `createTable` requires
 * `interestTag` (when given) to be "a known tag from the interest-tag
 * taxonomy," but no closed, canonical taxonomy is defined anywhere in the
 * docs — docs/PRODUCT.md explicitly calls its own table "a starting
 * point... not an exhaustive or final list." Rather than skip this
 * validation entirely (the spec does require *some* known-tag check) or
 * invent an unbounded, unreviewed taxonomy, this hard-codes the exact set
 * PRODUCT.md's table names, slugified. **Disclosed gap, not a silent
 * decision:** this starter list is Foundation/Phase-0-scoped and will need
 * a real taxonomy-management system (most likely Remote-Config-driven,
 * matching `addMember`'s `CREW_AT_CAPACITY` precedent, §3.2) before
 * Discover — which actually facets/filters on this field — makes the list
 *'s shape a user-facing product decision rather than an internal
 * validation detail. Tracked in TASKS.md, not left as an undocumented
 * hard-coded array a future engineer would have to reverse-engineer.
 */
export const KNOWN_INTEREST_TAGS: ReadonlySet<string> = new Set([
  'coffee',
  'lunch',
  'founder_dinners',
  'dinner',
  'board_games',
  'hiking',
]);

/** docs/API_SPEC.md §3.1 `createTable`: "optional, must be a known tag
 * from the interest-tag taxonomy" — see {@link KNOWN_INTEREST_TAGS}. */
export function isValidInterestTag(value: unknown): value is string | null | undefined {
  if (value === null || value === undefined) return true;
  return typeof value === 'string' && KNOWN_INTEREST_TAGS.has(value);
}

/** docs/DATABASE.md §3.2: `visibility` is `"open" | "closed"`. */
export function isValidVisibility(value: unknown): value is 'open' | 'closed' {
  return value === 'open' || value === 'closed';
}

interface LocationInput {
  geopoint?: unknown;
  venueId?: unknown;
  address?: unknown;
}

/**
 * docs/API_SPEC.md §3.1 `createTable`'s documented request shape:
 * `{ geopoint: {lat, lng}, venueId?: string, address: string }` — both
 * `geopoint` and `address` are required in this request contract (not
 * nullable), even though docs/DATABASE.md §3.2's stored schema allows both
 * to be `null` for a "Location TBD" Table. **Disclosed gap:** the
 * `isTBD`/`tbdConfirmBy` "Location TBD" flow docs/FEATURES.md names has no
 * reachable path through `createTable`'s current documented request shape
 * at all (no `isTBD` request field exists to set it true) — this
 * validator, and `createTable` below, are faithful to the request contract
 * as actually documented, not a guess at the TBD flow's shape. Every new
 * Table this milestone creates therefore has `location.isTBD: false`.
 */
export function isValidLocation(value: unknown): value is {
  geopoint: {lat: number; lng: number};
  venueId?: string | null;
  address: string;
} {
  if (typeof value !== 'object' || value === null) return false;
  const {geopoint, venueId, address} = value as LocationInput;

  if (typeof geopoint !== 'object' || geopoint === null) return false;
  const {lat, lng} = geopoint as {lat?: unknown; lng?: unknown};
  if (typeof lat !== 'number' || lat < -90 || lat > 90) return false;
  if (typeof lng !== 'number' || lng < -180 || lng > 180) return false;

  if (venueId !== undefined && venueId !== null && typeof venueId !== 'string') return false;
  if (typeof address !== 'string' || address.trim().length === 0) return false;

  return true;
}

const MIN_LEAD_TIME_MS = 60 * 60 * 1000; // "must be > now + 1 hour", createTable

/** docs/API_SPEC.md §3.1 `createTable`: "required, must be > now + 1
 * hour (min lead time)." */
export function isValidStartTime(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return false;
  return parsed > Date.now() + MIN_LEAD_TIME_MS;
}

const CAPACITY_HARD_FLOOR = 2;
const CAPACITY_HARD_CEILING = 8; // docs/DATABASE.md §3.2: corrected 2026-08 from an earlier 12

interface CapacityInput {
  min?: unknown;
  max?: unknown;
}

/** docs/API_SPEC.md §3.1 `createTable`: "required, 2 <= min <= max <= 8." */
export function isValidCapacity(value: unknown): value is {min: number; max: number} {
  if (typeof value !== 'object' || value === null) return false;
  const {min, max} = value as CapacityInput;
  if (typeof min !== 'number' || !Number.isInteger(min)) return false;
  if (typeof max !== 'number' || !Number.isInteger(max)) return false;
  return (
    min >= CAPACITY_HARD_FLOOR &&
    min <= max &&
    max <= CAPACITY_HARD_CEILING
  );
}

/**
 * docs/API_SPEC.md §3.1 `updateTable`'s documented patch surface:
 * `Partial<{ title, description, interestTag, location, startTime,
 * capacity, visibility }>`. Validates only the keys actually present in
 * `patch` (a `Partial`, per the request contract) — each present key
 * still runs through the same per-field validators `createTable` uses, so
 * a patch can't set a field to something `createTable` itself would have
 * rejected. Returns the list of invalid field names (empty if the whole
 * patch is valid) rather than a boolean, so the callable can report a
 * specific `invalid-argument` message.
 */
export function validateTablePatch(patch: unknown): string[] {
  if (typeof patch !== 'object' || patch === null) {
    return ['patch'];
  }
  const invalid: string[] = [];
  const p = patch as Record<string, unknown>;

  if ('title' in p && !isValidTitle(p.title)) invalid.push('title');
  if ('description' in p && !isValidDescription(p.description)) invalid.push('description');
  if ('interestTag' in p && !isValidInterestTag(p.interestTag)) invalid.push('interestTag');
  if ('location' in p && !isValidLocation(p.location)) invalid.push('location');
  if ('startTime' in p && !isValidStartTime(p.startTime)) invalid.push('startTime');
  if ('capacity' in p && !isValidCapacity(p.capacity)) invalid.push('capacity');
  if ('visibility' in p && !isValidVisibility(p.visibility)) invalid.push('visibility');

  return invalid;
}
