# features/account/

Screens 32-33, 35-36 (Profile / Me, Settings, Notification Center, Data Export / Delete Account) per `docs/SCREEN_SPECIFICATIONS.md`, backed by `docs/API_SPEC.md` §3.8's `exportUserData`/`deleteAccount`/`cancelPendingDeletion`/`revokeSessions` and `docs/FIREBASE.md`'s notification-preference schema.

Per `docs/ENGINEERING_GUIDELINES.md`'s feature-folder convention (see `features/README.md`), this will hold:

- `presentation/` — the 4 screen widgets, including Settings' dark-mode manual override (`docs/DESIGN_SYSTEM.md` §1.4) and its notification-category preference toggles.
- `application/` — Riverpod providers/notifiers for profile display, settings state, and the account-export/deletion flow.
- References into `app/lib/data/` for the user-profile repository, once it exists.

**Milestone F3 note:** this directory is a named, empty shell — routes for all 4 screens already exist in `core/routing/app_router.dart`, but no real screen or provider code lands here until Milestone F8 ("Notifications, Account/Settings, and hardening"), per `docs/IMPLEMENTATION_PLAN.md`.

**Explicitly not here:** Screen 34 (TableCrew+ Subscription) — subscription billing is out of Foundation/Phase 0 scope entirely (`docs/IMPLEMENTATION_PLAN.md` section 1), so it has no route and no planned home in this directory yet either.
