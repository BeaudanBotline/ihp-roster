# Engineering Backlog

## Purpose

This document converts the roadmap into a repo-specific engineering backlog for the current product direction:

- local, founder-managed rollout
- small number of venues
- standardised managed SaaS with venue as the current customer boundary
- no public self-serve venue signup in the near term

The backlog is ordered by what is most expensive to change later.

## Phase 0: do next

### 0.1 Membership-scoped authority model

Goal:

- make venue membership the canonical source of business authority

Implementation work:

- treat `users` as identity-only for venue permissions
- define canonical role values and capability mapping on `venue_memberships`
- remove controller/helper reliance on global business roles on `users`
- define role-change audit requirements and bootstrap defaults
- remove runtime dependence on `users.user_role` for venue business permissions

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Application/Helper/Controller.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Controller.hs)
- [Web/Controller/Prelude.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Prelude.hs)
- [Web/Controller/Sessions.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Sessions.hs)
- generated types after `regen-types`

### 0.2 Authentication and current venue resolution

Goal:

- every authenticated request operates inside a venue context

Implementation work:

- extend current auth flow to resolve current venue membership after login
- define how venue context is chosen:
  - single-venue-per-user for v1, or
  - explicit venue switcher if needed
- add helpers in controller prelude / application helpers for:
  - current venue
  - current venue membership
  - venue-scoped role checks
- ensure requests fail closed when no valid active venue membership exists

Repo impact:

- [Web/FrontController.hs](/home/beau/documents/projects/ihp-template/Web/FrontController.hs)
- [Application/Helper/Controller.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Controller.hs)
- [Web/Controller/Sessions.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Sessions.hs)
- [Web/Controller/Prelude.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Prelude.hs)
- [Web/Types.hs](/home/beau/documents/projects/ihp-template/Web/Types.hs)

### 0.3 Replace bootstrap-admin logic

Goal:

- remove public privilege bootstrapping

Implementation work:

- delete "first registered user becomes admin" behavior
- remove or constrain public registration flow
- add support-assisted venue bootstrap flow:
  - founder creates venue
  - founder invites initial venue owner/admin
- optionally keep worker invitation flow for later
- remove tests and helpers that encode first-user auto-admin behavior

Repo impact:

- [Web/Controller/Users.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Users.hs)
- [Web/View/Users/New.hs](/home/beau/documents/projects/ihp-template/Web/View/Users/New.hs)
- [Application/Helper/Controller.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Controller.hs)
- [specs/03-access-control-and-auth.md](/home/beau/documents/projects/ihp-template/specs/03-access-control-and-auth.md)

Decision required:

- whether public signup is removed entirely now or left disabled by default behind config

### 0.4 Snapshot-based pay/config stability design

Goal:

- make historical pay behavior reproducible before broader payroll-adjacent use

Implementation work:

- define the pay/config snapshot schema created by venue admin bulk-save actions
- define how approved timesheets and exports reference the applicable snapshot version
- define venue admin page semantics for draft edits versus saved version creation

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Application/Helper/Pay.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Pay.hs)
- [specs/06-pay-engine.md](/home/beau/documents/projects/ihp-template/specs/06-pay-engine.md)

## Phase 1: venue-scope the product

### 1.1 Refactor queries to venue scope

Goal:

- no core business query should rely on global tables without venue filtering

Implementation work:

- audit all queries in controllers/helpers
- add explicit venue filters everywhere
- add helper functions for common scoped queries
- remove any assumptions that the dataset is globally shared

Repo impact:

- [Web/Controller/RosterWeeks.hs](/home/beau/documents/projects/ihp-template/Web/Controller/RosterWeeks.hs)
- [Web/Controller/Timesheets.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Timesheets.hs)
- [Web/Controller/LeaveRequests.hs](/home/beau/documents/projects/ihp-template/Web/Controller/LeaveRequests.hs)
- [Web/Controller/Profiles.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Profiles.hs)
- [Web/Controller/Staff.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Staff.hs)
- [Application/Helper/Pay.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Pay.hs)
- [Application/Helper/Conflict.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Conflict.hs)

### 1.2 Venue-owned configuration

Goal:

- remove remaining singleton/global config assumptions from business logic

Implementation work:

- keep `venue_config` as the venue-owned boundary
- make pay/config tables venue-owned where needed
- preserve deterministic calculation behavior during migration
- ensure historical pay/config strategy from Phase 0.4 is reflected in schema and helpers
- build the venue admin bulk-edit/save workflow that creates new immutable pay/config versions

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Application/Helper/Controller.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Controller.hs)
- pay and roster helpers/controllers that currently assume singleton config

### 1.3 Update tests for venue isolation

Goal:

- prove that cross-venue access is blocked

Implementation work:

- add controller tests for unauthorized cross-venue access
- add tests for venue-scoped visibility of roster, timesheet and leave data
- add tests for venue bootstrap flow
- add tests proving global `users` fields cannot bypass venue membership checks

Repo impact:

- [Test/Controller/](/home/beau/documents/projects/ihp-template/Test/Controller)
- [Test/Main.hs](/home/beau/documents/projects/ihp-template/Test/Main.hs)

## Phase 2: record integrity and auditability

### 2.1 Audit event infrastructure

Goal:

- durable audit trail for sensitive actions

Schema work:

- add `audit_events`

Fields should include at minimum:

- venue id
- actor user id
- event type
- target table / target id
- timestamp
- payload or before/after summary
- source channel

Implementation work:

- add helper/service for writing audit events
- emit audit events for:
  - timesheet approval/unapproval
  - leave approval/denial/deletion
  - venue role changes
  - export generation/download
  - support access if added

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Application/Helper/Controller.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Controller.hs)
- relevant controllers

### 2.2 Correction-safe timesheets

Goal:

- stop relying on destructive overwrite semantics for payroll-adjacent records

Implementation work:

- choose one model:
  - versioned `timesheet_entries`
  - separate correction rows
  - immutable event log plus derived current row
- change update/delete flows accordingly
- ensure UI reflects corrected/superseded state cleanly

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Web/Controller/Timesheets.hs](/home/beau/documents/projects/ihp-template/Web/Controller/Timesheets.hs)
- [Web/View/Timesheets/Index.hs](/home/beau/documents/projects/ihp-template/Web/View/Timesheets/Index.hs)
- [Web/View/Timesheets/Edit.hs](/home/beau/documents/projects/ihp-template/Web/View/Timesheets/Edit.hs)
- [Web/View/Timesheets/New.hs](/home/beau/documents/projects/ihp-template/Web/View/Timesheets/New.hs)

### 2.3 Correction-safe leave status history

Goal:

- preserve approval provenance and status history

Implementation work:

- add leave status event/history model or versioning
- stop treating destructive delete as the normal lifecycle for business-use leave records

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Web/Controller/LeaveRequests.hs](/home/beau/documents/projects/ihp-template/Web/Controller/LeaveRequests.hs)
- [Web/View/LeaveRequests/Index.hs](/home/beau/documents/projects/ihp-template/Web/View/LeaveRequests/Index.hs)

### 2.4 Historical pay/config implementation

Goal:

- turn the chosen historical stability model into enforceable application behavior

Implementation work:

- implement snapshot/version records created from venue admin save actions
- update SQL pay functions to resolve against explicit historical rule context
- version exports so old payroll-adjacent outputs remain interpretable
- add tests for recalculating historical periods after later config changes

Repo impact:

- [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Application/Helper/Pay.hs](/home/beau/documents/projects/ihp-template/Application/Helper/Pay.hs)
- SQL functions in [Application/Schema.sql](/home/beau/documents/projects/ihp-template/Application/Schema.sql)
- [Test/PaySpec.hs](/home/beau/documents/projects/ihp-template/Test/PaySpec.hs)

## Phase 3: exports and managed-service operations

### 3.1 Export job infrastructure

Goal:

- treat exports as controlled disclosures

Schema work:

- add `export_jobs`
- optionally add `export_files`

Implementation work:

- central export service
- signed or expiring download flow
- audit event emission for export creation and download
- schema versioning for exports

Repo impact:

- new export controller(s)
- [Web/Types.hs](/home/beau/documents/projects/ihp-template/Web/Types.hs)
- [Web/Routes.hs](/home/beau/documents/projects/ihp-template/Web/Routes.hs)
- [Web/FrontController.hs](/home/beau/documents/projects/ihp-template/Web/FrontController.hs)
- new helper/service modules under [Application/Helper/](/home/beau/documents/projects/ihp-template/Application/Helper)

### 3.2 Founder-managed support workflow

Goal:

- support early clients without invisible or uncontrolled access

Implementation work:

- define internal support access flow
- add support-access audit logging if in-app support tools are built
- document when manual DB access is forbidden versus exceptional

This may begin as documentation plus audit policy before dedicated support screens exist.

## Phase 4: security hardening before first paying clients

### 4.1 Session and auth hardening

Implementation work:

- review session secret handling
- review cookie security settings
- add rate limiting for login and export actions
- evaluate MFA path for privileged venue roles

Repo impact:

- [Config/Config.hs](/home/beau/documents/projects/ihp-template/Config/Config.hs)
- deployment config under [Config/nix/hosts/production/](/home/beau/documents/projects/ihp-template/Config/nix/hosts/production)

### 4.2 Frontend third-party asset review

Goal:

- reduce uncontrolled offshore exposure on authenticated pages

Implementation work:

- replace CDN-hosted frontend assets with local/vendor-served assets where practical
- document any remaining offshore services

Repo impact:

- [Web/View/Layout.hs](/home/beau/documents/projects/ihp-template/Web/View/Layout.hs)
- [static/vendor/](/home/beau/documents/projects/ihp-template/static/vendor)

### 4.3 Security header baseline

Implementation work:

- add CSP strategy appropriate for current asset loading model
- add HSTS, frame, referrer and related headers as appropriate

Repo impact:

- likely [Config/Config.hs](/home/beau/documents/projects/ihp-template/Config/Config.hs) and/or deployment config

## Phase 5: documentation and first-client pack

These are not purely engineering tasks, but engineering should support them.

Deliverables:

- privacy policy draft based on actual architecture
- customer terms draft
- onboarding checklist
- subprocessor inventory
- retention schedule
- incident/breach checklist

Engineering support required:

- accurate hosting and data flow description
- export behavior description
- support-access description
- backup and restore description

## Recommended implementation sequence for the repo

1. Membership-scoped authority model.
2. Current venue resolution and venue role helpers.
3. Removal of bootstrap-admin and public signup assumptions.
4. Historical pay/config stability design.
5. Venue-scoping of all business queries and config.
6. Venue isolation tests.
7. Audit-event infrastructure.
8. Correction-safe timesheets.
9. Correction-safe leave history.
10. Historical pay/config implementation.
11. Export job infrastructure.
12. Session/security hardening and third-party asset review.

## Suggested "stop after this" milestone for first pilot clients

The first realistic milestone for local pilot venues is:

- venue model complete
- business authority lives on venue memberships
- no public signup
- venue-scoped auth complete
- audit events for sensitive actions
- correction-safe timesheet handling
- historical pay/config model chosen and implemented for approved records
- basic export job logging
- privacy policy draft
- customer terms draft
- backup and restore tested

That is enough to start structured pilot conversations without pretending the product is enterprise-ready.
