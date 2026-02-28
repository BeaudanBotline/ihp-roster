# Roster and Conflict Rules

## Roster lifecycle

1. Week created in draft mode (`is_live = false`).
2. Managers/Admins edit assignments.
3. Managers/Admins can publish (`is_live = true`).
4. Staff sees only published weeks.

## Copy week

- Copy operation duplicates source week structure and assignments into target `week_offset`.
- Copied week is always created as draft (`is_live = false`).

## Assignment filtering

Roster assignment UI must support filter toggles:

- Hide staff at ideal shifts.
- Hide staff on leave.
- Hide staff with preference conflicts.

## Conflict flagging

A slot assignment can produce conflict flags. Priority order and visual severity for display:

**Critical Conflicts (Rendered as Dark Red dropdown background):**
1. Duplicate assignment conflict.
2. Leave conflict.
3. Late-to-Early conflict.

**Advisory Conflicts (Rendered as Light Pink dropdown background):**
4. Availability refusal conflict.
5. Ideal-shift threshold exceeded.

## Late-to-Early rule

- Evaluate **start-to-start gap** between a staff member’s relevant consecutive shifts.
- If gap is less than `venue_config.late_to_early_min_start_gap_minutes`, flag conflict.
- This rule is evaluable from roster plan data even when explicit end times are unknown.

## Temporal invariants

- `week_offset` is based on global fixed epoch.
- `day_offset` constrained to 0..6.
- Roster calculations should be timezone-aware via `venue_config.timezone`.
