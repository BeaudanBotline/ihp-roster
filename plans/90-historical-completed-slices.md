# Historical Completed and Superseded Slices

This file preserves completed or superseded detail that no longer belongs in the root roadmap.

## Completed Foundation Slices

### 0.1 Core schema skeleton
- **Status:** [x]
- Expanded `Application/Schema.sql` from auth-only to core domain skeleton.
- Added `Test/SchemaSpec.hs` to assert generated model types compile.
- Verification run: `regen-types`, `typecheck`, and `test` passed.

### 0.2 Venue config singleton and bootstrap seed
- **Status:** [x]
- Historical note only. This reflected the pre-venue-scoped config shape and bootstrap seed work.

### 0.3 Enum/value normalization for statuses and roles
- **Status:** [x]
- Added normalized constraints/helpers for legacy user-role and leave-status handling.
- Some of this work now needs migration toward membership-scoped authority.

## Completed Auth Slices

### 1.2 Mandatory profile completion gate
- **Status:** [x]
- `ProfilesController` and required profile flow are implemented.

### 1.3 Role-based authorization helpers
- **Status:** [x]
- Helpers exist, but should be migrated away from `users.user_role` for venue business permissions.

## Superseded Slice

### 1.1 First-user bootstrap admin
- **Status:** [!]
- Implemented historically, but superseded by founder-managed venue bootstrap.
- Remove this behavior from live code and tests as part of pipeline 00.
