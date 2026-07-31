# TableCrew

> **Real Conversations. Real Connections.**

We believe the best opportunities in life begin with a conversation.

TableCrew makes it effortless to bring people together over coffee, lunch, and dinner—whether they're lifelong friends, new arrivals to a city, fellow founders, creators, mentors, or simply people who share a common interest.

Our goal isn't to maximize screen time.

It's to maximize meaningful time around a table.

**Make it effortless for anyone, anywhere, to build real friendships around a table.**

This repository contains the complete product, design, engineering, and business documentation for TableCrew — a platform, not a mobile app narrowly defined (see `docs/PRODUCT.md`), whose primary current surface is a mobile app. It serves as the single source of truth for building the company and the platform. It does not (yet) contain application code. See `CLAUDE.md` for the rule on when code is allowed to be written here.

## What TableCrew is, in one paragraph

People are more digitally connected and more socially isolated than any generation before them. The friction isn't a lack of desire to see people, it's the coordination cost: finding a time, agreeing on a place, tracking who's actually coming, and doing it again next month. TableCrew removes that friction with three concepts — a **Table** (a small-group gathering, typically between 2 and 8 people, with recommended sizes that vary by activity — coffee and mentorship skew smaller and more intimate, dinner and founder-dinner formats sit in the middle, board games and hiking flex toward the larger end), a **Crew** (a persistent friend group that tables together repeatedly), and **Discover** (a way to meet curated new people through Open Tables). Full detail, including the activity-by-activity recommendation table, is in `docs/PRODUCT.md`.

## Start here, depending on your role

If you are joining as an engineer, start with `docs/PRODUCT.md`, then `docs/PRD.md`, then `docs/ARCHITECTURE.md`, then `docs/ENGINEERING_GUIDELINES.md`. `CLAUDE.md` describes how AI coding agents (including Claude) should operate in this repository once we begin implementation.

If you are joining as design, brand, or marketing, start with `docs/PRODUCT.md`, then `docs/USER_PERSONAS.md`, then `docs/DESIGN_SYSTEM.md`, `docs/BRAND_GUIDELINES.md`, and `docs/COPY_GUIDELINES.md`.

If you are an investor or prospective hire evaluating the company, start with `docs/VISION.md`, `docs/MISSION.md`, and `docs/INVESTOR_OVERVIEW.md`.

## Full document index

### Company foundation
- `docs/MISSION.md` — why the company exists, day to day
- `docs/VISION.md` — the 10-year picture if the mission succeeds
- `docs/VALUES.md` — the six operating principles and their real trade-offs
- `docs/PRODUCT.md` — the single-page canonical description of the product; the source of truth if any two documents disagree

### Product
- `docs/PRD.md` — full functional and non-functional requirements
- `docs/USER_PERSONAS.md` — the five people we design for, in priority order
- `docs/USER_RESEARCH.md` — the research methodology and findings the personas are built from
- `docs/ROADMAP.md` — the five-phase plan from single-city MVP to global scale
- `docs/FEATURES.md` — the full MoSCoW-prioritized feature backlog
- `docs/SUCCESS_METRICS.md` — the North Star metric, supporting metrics, and guardrails

### Engineering
- `docs/ARCHITECTURE.md` — system architecture and the Flutter + Firebase decision, justified
- `docs/DATABASE.md` — the full Firestore data model
- `docs/API_SPEC.md` — the Cloud Functions API surface
- `docs/FIREBASE.md` — which Firebase products we use and why
- `docs/ENGINEERING_GUIDELINES.md` — repo conventions, code style, review process, onboarding
- `docs/SECURITY.md` — identity verification, safety systems, privacy compliance
- `docs/TESTING.md` — the testing pyramid and QA process
- `docs/DEPLOYMENT.md` — release process, environments, rollback
- `docs/CI_CD.md` — the CI/CD pipeline
- `docs/LEGAL.md` — entity structure, ToS/insurance/liability, regulatory risk by jurisdiction (added during Series A diligence)
- `docs/SERIES_A_DILIGENCE_REVIEW.md` — the adversarial diligence pass: every contradiction, gap, and risk found across this repository, and what was fixed
- `docs/ARCHITECTURE_READINESS_REVIEW.md` — the pre-engineering readiness check across product alignment, data/feature coverage, API completeness, security, analytics, notifications, offline behavior, and error states — confirms the knowledge base is actually buildable, not just internally consistent
- `docs/IMPLEMENTATION_PLAN.md` — the Staff Engineer/Technical Lead implementation plan for the Foundation engineering effort that delivers `docs/ROADMAP.md`'s Phase 0: milestones, deliverables, dependencies, order of work, and pre-implementation recommendations
- `docs/COMPETITOR_ANALYSIS.md` — product-facing teardown of Meetup, Timeleft, Bumble For Friends, Geneva, Partiful, and OpenTable (reservation-flow only): what each does well, what users complain about, what to emulate, what to avoid
- `docs/SCREEN_SPECIFICATIONS.md` — the binding Product/Design/Engineering contract: a full spec (purpose, entry/exit points, components, API calls, validation, loading/empty/offline states, analytics, accessibility, future enhancements) for every one of the app's 36 screens
- `docs/WIREFRAMES.md` — low-fidelity layout wireframes for all 36 screens, derived from `docs/SCREEN_SPECIFICATIONS.md`, each with a Notes callout naming a specific UX or implementation risk to resolve before Flutter work begins

### Design and brand
- `docs/DESIGN_SYSTEM.md` — color, type, components, accessibility
- `docs/BRAND_GUIDELINES.md` — name story, voice, imagery
- `docs/COPY_GUIDELINES.md` — UX writing standards and terminology glossary

### Growth
- `docs/MARKETING.md` — positioning, channels, city-launch playbook
- `docs/SEO.md` — organic content strategy and App Store Optimization
- `docs/INVESTOR_OVERVIEW.md` — market sizing, competitive landscape, business model, risks

### Company operations
- `CLAUDE.md` — how AI coding agents should work in this repository
- `TASKS.md` — the active engineering task backlog for the current phase
- `CHANGELOG.md` — the dated history of material changes to this knowledge base
- `EXECUTIVE_SUMMARY.md` — a leadership-level summary of the full knowledge base and the state of the company

## Current status

As of this writing, TableCrew is pre-build: the company has a complete knowledge base (this repository) and has not yet written application code. The next milestone, per `docs/ROADMAP.md`, is Phase 0 — a single-city MVP supporting Crew-first Table creation only, with Discover intentionally deferred to Phase 1 so that identity verification and safety infrastructure (`docs/SECURITY.md`) can be built before any stranger-matching feature ships. See `TASKS.md` for the specific engineering tasks that make up Phase 0.

## Product Principles

Conversation over content.
Trust before growth.
Quality over quantity.
Offline relationships over online engagement.
Community before scale.

## Initial Launch
📍 Hyderabad, India
Our launch strategy is intentionally city-first.
Rather than expanding rapidly, we will build density and community in Hyderabad before expanding to additional cities.
Future expansion includes:
Bangalore
Pune
Chennai
Mumbai
Delhi
International markets

## Core User Journey
Create an account.
Build your profile.
Select your interests.
Discover nearby tables.
Request to join a conversation.
Meet in person.
Build meaningful relationships.
Grow your reputation within the community.

## Technology Stack
#Mobile
Flutter
Riverpod
GoRouter
Material 3
#Backend
Firebase Authentication
Cloud Firestore
Cloud Functions
Firebase Storage
Firebase Cloud Messaging
Search
Typesense
#Analytics
Firebase Analytics
Crashlytics
Mixpanel
#Payments
Stripe (future)

## Repository Structure

See "Full document index" above for the complete, current file list with descriptions — this section previously repeated a partial, manually-typed copy of that list, which had already drifted out of date (missing `VALUES.md`, `MISSION.md`, `FEATURES.md`, `SUCCESS_METRICS.md`, `USER_RESEARCH.md`, `FIREBASE.md`, `CI_CD.md`, `COPY_GUIDELINES.md`, `MARKETING.md`, `SEO.md`, `INVESTOR_OVERVIEW.md`, `LEGAL.md`, `CHANGELOG.md`, and `EXECUTIVE_SUMMARY.md`). Keeping one authoritative list, rather than two that can silently diverge, is the fix.
## Development Principles
We prioritize:
Clean Architecture
SOLID principles
Test-driven development where appropriate
Production-quality code
Small, reviewable pull requests
Comprehensive documentation
Security by design
Accessibility
Scalability

## Success Metrics
Our North Star Metric:
Tables Attended per Active User per Month
Supporting metrics include:
Meaningful conversations completed
Repeat attendance
Table completion rate
Host retention
Guest retention
Community health
Safety incidents
Net Promoter Score (NPS)
We deliberately avoid optimizing for vanity metrics such as screen time or endless scrolling.

##AI-Assisted Development

This repository is designed to be developed with AI-assisted engineering.
Before implementing any feature:
Read the relevant documentation in the docs/ directory.
Understand the product intent before writing code.
Follow the documented architecture and engineering guidelines.
Update documentation when introducing changes.
Include tests for all production code.
Never implement undocumented product behavior without first updating the relevant specification.

## Contribution Workflow
Understand the feature requirements.
Review related documentation.
Design before coding.
Implement incrementally.
Write tests.
Update documentation.
Submit for review.

## Long-Term Vision
TableCrew is more than an application.
It is an effort to help people build friendships, discover mentors, exchange ideas, strengthen local communities, and create opportunities through meaningful conversations.
We believe the next great friendship, career opportunity, business partnership, or life-changing idea can begin with one shared table.
Welcome to TableCrew.
