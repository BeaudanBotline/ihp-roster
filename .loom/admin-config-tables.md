# Agent Execution Prompt

You are implementing this application incrementally.

## Assigned objective

Implement the tracked `admin-config-tables` workstream for this repository.

This corresponds to:

- roadmap: `IMPLEMENTATION_PLAN.md`
- pipeline: `plans/40-pay-config-and-admin.md`
- next open slice: `7.1 Admin screens for config tables`

## Required read order

1. `AGENTS.md`
2. `IMPLEMENTATION_PLAN.md`
3. `plans/40-pay-config-and-admin.md`
4. The most relevant spec files under `specs/`, especially pay, admin, UI, and testing guidance
5. Relevant subdirectory `AGENTS.md` files before editing files in those areas

## Required process

1. Implement slice `7.1 Admin screens for config tables` first.
2. Keep the work aligned with the existing snapshot-based pay/config model from pipeline 40.
3. Respect venue scoping and correction-safe history assumptions already established by completed pipelines.
4. Keep the admin flow focused on config-table screens rather than drifting into later slices unless necessary to complete `7.1`.
5. Add or update tests that cover the changed behavior.
6. Run the required verification commands from repo guidance.
   - At minimum, run `direnv exec . typecheck`.
   - Run `direnv exec . test` for backend, controller, or schema changes.
   - Run any relevant admin or end-to-end coverage for the changed workflow if the slice touches UI flows.
7. Work on branch `weaver/admin-config-tables`.
8. If `weaver/admin-config-tables` does not exist yet, create it from `roster`.
9. Update `IMPLEMENTATION_PLAN.md` with completion notes if and only if the slice is actually complete.
10. Commit the changes when the slice or a coherent milestone is complete.
11. Push `weaver/admin-config-tables` when the assigned work is complete and verification has passed for the changed scope.

## Constraints

- Do not pick a different task.
- Do not reintroduce global-role or cross-venue assumptions.
- Do not rewrite the historical snapshot model.
- If blocked by unclear product requirements, stop and ask targeted clarification questions instead of inventing policy.
- Do not mark the slice complete unless implementation and verification actually support that claim.

## Output expectation

- Progress focused on `7.1 Admin screens for config tables`
- Passing verification for the changed scope
- Tests covering the new behavior
- Updated roadmap notes if the slice is completed
- One commit
- Pushed branch
