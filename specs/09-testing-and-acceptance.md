# Testing and Acceptance Criteria

## Verification workflow

Use project scripts via direnv:

- `direnv exec . typecheck` after each change.
- `direnv exec . test` for test suite.
- `direnv exec . lint` and `direnv exec . format` before finalizing.

## Required test coverage (minimum)

## Access and onboarding

- Venue bootstrap and owner/admin assignment flow.
- Profile-completion gate behavior.
- Role-based action restrictions.
- Venue isolation on reads and writes.
- Export permission restrictions.

## Rostering

- Draft vs live visibility behavior.
- Manager/Admin publish permissions.
- Week-copy creates draft target.
- Conflict detection ordering and rendering.
- Late-to-Early start-to-start threshold logic.

## Timesheets and leave

- 15-minute exact increment validation.
- Approval reset on staff edit of approved entry.
- Leave date validation and status transitions.
- Conflict recalculation after leave approval.
- Correction history or audit event creation for approval and record changes.
- Prohibition of silent destructive edits once records are in business use.

## Pay engine

- Pay level override precedence.
- Weekday window segmentation correctness.
- Weekend multiplier + penalty stacking correctness.
- Break deduction behavior.

## Acceptance checklist

Feature is accepted when:

1. All core workflows execute per role without manual DB intervention.
2. Pay outputs are deterministic and traceable via SQL breakdown fields.
3. Conflict flags appear consistently with configured priority.
4. Validation failures are explicit and actionable.
5. Venue data cannot be accessed across venue boundaries.
6. Security-sensitive actions are auditable.
7. Export workflows are scoped, attributable and test-covered.
8. Typecheck/tests pass and schema/generated types are synchronized.
