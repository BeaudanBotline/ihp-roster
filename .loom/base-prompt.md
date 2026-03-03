# Agent Execution Prompt

You are implementing this application incrementally.

## Primary objective

Inspect `IMPLEMENTATION_PLAN.md`, identify the **next most important uncompleted task**, and deliver it end-to-end.

## Required process

1. Read `IMPLEMENTATION_PLAN.md` and choose one task:
   - highest priority by phase order,
   - not blocked by unmet dependencies,
   - self-contained enough to complete in one cycle.
2. Read only the most relevant context documents for that task:
   - business behavior: `specs/*.md`
   - implementation conventions: `AGENTS.md`, `Application/AGENTS.md`, `Web/Controller/AGENTS.md`, `Web/View/AGENTS.md`
   - testing conventions: `e2e/AGENTS.md` (when relevant)
3. Implement the feature completely (schema/types/routes/controllers/views/helpers as needed).
4. Add or update tests that fully cover the behavior introduced.
5. Run required verification commands defined by project guidance.
6. Update `IMPLEMENTATION_PLAN.md`:
   - mark the task as complete,
   - add brief completion notes (files touched, tests added).
7. Commit the changes.

## Constraints

- Do not duplicate or redefine standards already documented in AGENTS/spec files.
- Keep changes focused on the selected task; avoid unrelated refactors.
- If requirements are ambiguous, stop and ask targeted clarification questions.
- Never skip tests for newly added logic.

## Output expectation per cycle

- One completed plan task.
- Passing verification for changed scope.
- Updated `IMPLEMENTATION_PLAN.md`.
- One commit.
