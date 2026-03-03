# Implementation Roadmap

This file is the canonical roadmap for implementation order.

Use it to answer:
- what the current priorities are
- which pipelines can run in parallel
- which dependencies must land first

Do not treat the pipeline files under `plans/` as independent sources of truth for ordering. They hold the detailed task breakdowns for a specific workstream, but this file defines the global sequence.

Business requirements remain canonical in `specs/`.

## Planning Structure

- Root roadmap: `IMPLEMENTATION_PLAN.md`
- Detailed pipeline plans:
  - `plans/00-auth-bootstrap-memberships.md`
  - `plans/10-venue-scoping-audit-exports.md`
  - `plans/20-roster-and-conflicts.md`
  - `plans/30-timesheets-and-leave.md`
  - `plans/40-pay-config-and-admin.md`
  - `plans/50-release-readiness.md`
- Template extraction (backport to master):
  - `plans/60-template-extraction.md`
- Historical completed and superseded slices:
  - `plans/90-historical-completed-slices.md`

## Current Direction

The current implementation direction is:

- local, founder-managed rollout
- small number of venues
- standardised managed SaaS with venue as the current customer boundary
- no public self-serve venue creation in the near term

The current high-priority business-logic decisions are:

- business authority comes from `venue_memberships`, not `users`
- privileged access uses founder-managed venue bootstrap, not bootstrap-admin signup
- payroll-adjacent records use correction-safe history
- pay/config history uses immutable snapshot versions created by venue admin bulk-save actions

## Status Legend

- `[ ]` Not started
- `[-]` In progress
- `[x]` Done
- `[!]` Superseded or legacy context only

## Global Order

These steps are globally ordered. Detailed task breakdowns live in the linked pipeline files.

1. Membership-scoped auth and bootstrap hardening
   - Plan: `plans/00-auth-bootstrap-memberships.md`
   - Must land before broad controller/query work.
2. Venue-scoped queries, audit foundations, and export primitives
   - Plan: `plans/10-venue-scoping-audit-exports.md`
   - Depends on membership-scoped auth helpers.
3. Timesheet/leave correction-safe flows
   - Plan: `plans/30-timesheets-and-leave.md`
   - Depends on auth and audit foundations.
4. Snapshot-based pay/config versioning and venue admin save workflow
   - Plan: `plans/40-pay-config-and-admin.md`
   - Depends on venue scoping and should shape exports.
5. Roster and conflict UX expansion
   - Plan: `plans/20-roster-and-conflicts.md`
   - Can proceed in parallel where it does not conflict with auth/scoping changes.
6. Release readiness, hardening, and acceptance sweep
   - Plan: `plans/50-release-readiness.md`
   - Depends on the foundations above.

## Active Pipelines

### Pipeline 00 — Auth, Bootstrap, Memberships
- **Status:** [-]
- **File:** `plans/00-auth-bootstrap-memberships.md`
- **Focus:** remove bootstrap-admin logic, resolve current venue membership on each request, and stop using `users` as the source of venue business authority.
- **Progress:** A.2 is complete. Request init now resolves current venue/membership context from active `venue_memberships`, and operational controllers enforce venue-scoped role/access checks.

### Pipeline 10 — Venue Scoping, Audit, Exports
- **Status:** [ ]
- **File:** `plans/10-venue-scoping-audit-exports.md`
- **Focus:** enforce venue-scoped queries everywhere, add audit primitives, and introduce export job infrastructure.

### Pipeline 20 — Roster and Conflicts
- **Status:** [-]
- **File:** `plans/20-roster-and-conflicts.md`
- **Focus:** roster page workflow, conflict rendering, roster-side staff editing, and related UX slices.
- **Note:** parts of this stream are already delivered; remaining work should respect auth/scoping foundations.

### Pipeline 30 — Timesheets and Leave
- **Status:** [ ]
- **File:** `plans/30-timesheets-and-leave.md`
- **Focus:** exact time validation, approval workflows, edit windows, leave lifecycle, and correction-safe history.

### Pipeline 40 — Pay Config and Admin
- **Status:** [ ]
- **File:** `plans/40-pay-config-and-admin.md`
- **Focus:** SQL pay engine, immutable pay/config snapshot versions, and the venue admin bulk-edit/save workflow.

### Pipeline 50 — Release Readiness
- **Status:** [ ]
- **File:** `plans/50-release-readiness.md`
- **Focus:** testing coverage, UI polish, reporting, security hardening, and release acceptance.

### Pipeline 60 — Template Extraction
- **Status:** [-]
- **File:** `plans/60-template-extraction.md`
- **Focus:** extract reusable, project-agnostic infrastructure (dev automation, overlay system, dark theme, AGENTS.md, e2e helpers) from `roster` back to `master` so master serves as a powerful general-purpose IHP template.
- **Note:** targets `master` branch only. No domain code crosses over. Can proceed independently of all other pipelines.
- **Progress:** Phase 1 is complete on `master`: Slice 1.1 via `138f3c2` plus compatibility follow-up `a266d95`, Slice 1.2 via `11af962`, Slice 1.3 via `21c5f38`, and Slices 1.4-1.6 via `43ffa4b`. `master` now includes the Nix empty-string fix, dev lifecycle scripts, `hlint -XQuasiQuotes`, the `IHP_LIB` fallback for `make db`, the `Config.hs` trailing newline fix, and the authenticated `screenshot-page` helper. Phase 2 is now fully complete: Slices 2.1-2.3 via `3faa95c` and Slice 2.4 via `f23d928`, covering Bootstrap 5.3.8, the generic dark-mode CSS foundation, the dark-shell layout/header, and auth-facing view normalization onto semantic theme classes. Phase 3 is complete via `c72d2a3`, which adds the generic overlay helpers, dialog/toast JavaScript, and flash-toast layout wiring. Phase 4 is complete via `24b7691`, which generalizes the root and subdirectory `AGENTS.md` files for template use without carrying over roster-specific guidance. Phase 5 is complete via `9634255`, which adds the generic HTMX helpers, the profile-completion stub comment, and the time parsing utilities to `Application/Helper/Controller.hs`.

## Parallelism Rules

These pipelines can overlap when they respect the dependency constraints above:

- `plans/20-roster-and-conflicts.md` can progress in parallel with auth/scoping work if it does not reintroduce global-role or cross-venue assumptions.
- `plans/30-timesheets-and-leave.md` can progress alongside `plans/40-pay-config-and-admin.md` once the snapshot/version contract is fixed.
- `plans/50-release-readiness.md` should mostly trail the others, but test additions can happen incrementally.
- `plans/60-template-extraction.md` targets `master` only and has no dependency on any other pipeline. It can proceed fully in parallel.

## Read Order For Agents

When working a feature:

1. Read the relevant canonical spec files in `specs/`.
2. Read this roadmap for global ordering and dependencies.
3. Read only the relevant file under `plans/`.
4. Check `plans/90-historical-completed-slices.md` only if prior implementation notes or superseded work matter.
