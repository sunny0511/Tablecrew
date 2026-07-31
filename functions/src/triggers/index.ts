/**
 * Firestore/Auth-triggered functions (as opposed to client-callable ones),
 * per docs/ENGINEERING_GUIDELINES.md's separation of triggers from
 * callables. E.g., the Table→Typesense sync trigger (docs/ARCHITECTURE.md
 * §5.5, Phase 1) and the scheduled Firestore export job
 * (docs/ARCHITECTURE.md §8).
 *
 * Scaffold note (Milestone F0): no triggers implemented yet.
 */

export {};
