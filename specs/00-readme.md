# IHP Application Specifications

This folder contains the canonical specification set for this project:

- IHP (Haskell MVC)
- PostgreSQL
- HSX views
- Bootstrap 5.2.1

## Canonical decisions

1. UI requirements target **Bootstrap 5**.
2. Pay engine uses a **Mixed architecture**:
   - PostgreSQL functions for canonical pay calculations.
   - Haskell for orchestration/report shaping.
3. Late-to-Early conflict is based on **start-to-start gap**.
4. Late-to-Early threshold is a **global venue config** value.
5. `week_offset_epoch` is a **global fixed epoch**.
6. Weekend multipliers **stack** with penalties.
7. Kitchen flag is out of scope.
8. Timesheet time input requires **exact 15-minute increments**.
9. Trial staff are placeholders only; no conversion flow.
10. **Managers and Admins can publish** rosters.

## Document map

- `01-product-scope.md`
- `02-domain-model.md`
- `03-access-control-and-auth.md`
- `04-roster-and-conflict-rules.md`
- `05-timesheets-and-leave.md`
- `06-pay-engine.md`
- `07-ui-bootstrap-spec.md`
- `08-ihp-implementation-spec.md`
- `09-testing-and-acceptance.md`
