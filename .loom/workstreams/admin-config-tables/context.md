# Admin Config Tables Context

## Objective

Implement the tracked `admin-config-tables` workstream for `ihp-roster`.

This is pipeline `40` slice `7.1 Admin screens for config tables`.

## Required read order

1. `AGENTS.md`
2. `IMPLEMENTATION_PLAN.md`
3. `plans/40-pay-config-and-admin.md`
4. The most relevant spec files under `specs/`, especially pay, admin, UI, and testing guidance
5. Relevant subdirectory `AGENTS.md` files before editing files in those areas
6. `.loom/workstreams/admin-config-tables/handoff.md`

## Branch expectations

- Base branch: `roster`
- Work branch: `weaver/admin-config-tables`

## Scope constraints

- Start with the branch stabilization pass before taking on new work in slice `7.1`.
- Keep the work aligned with the existing snapshot-based pay/config model from pipeline 40.
- Respect venue scoping and correction-safe history assumptions already established by completed pipelines.
- Keep the admin flow focused on config-table screens rather than drifting into later slices unless necessary to complete `7.1`.

## Current external dependency

The current blocker is outside this repo's application code. The Loom weaver runtime is failing before repo execution begins because the current daemon-backed Nix image design assumes root, while the Loom pod security context is enforcing non-root execution.

Do not spend more time iterating on app code until the runtime problem is resolved or the task is explicitly reframed to continue outside Loom.
