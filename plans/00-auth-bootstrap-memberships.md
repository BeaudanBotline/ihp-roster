# Pipeline 00 — Auth, Bootstrap, Memberships

Read after `IMPLEMENTATION_PLAN.md`.

## Goal

Make venue membership the canonical source of business authority and remove bootstrap-admin/public-signup assumptions.

## Scope

- current venue and membership resolution
- venue-scoped role checks from `venue_memberships`
- founder-managed venue bootstrap
- removal of first-user auto-admin logic
- profile-completion and auth guard alignment

## Non-Goals

- export job implementation
- pay/config snapshot implementation
- roster UX polish unrelated to auth/scoping

## Dependencies

- Uses existing venue schema from `Application/Schema.sql`
- Must land before broad venue-scoped query refactors

## Slices

### A.2 Current venue resolution and venue-scoped auth helpers
- **Status:** [ ]
- **Goal:** Ensure every authenticated request operates inside an explicit venue context and resolves business authority from membership data.
- **Deliverables:**
  - Add current-venue and current-membership helpers in shared controller code.
  - Resolve venue context after login.
  - Add venue-scoped role checks based on `venue_memberships`.
  - Remove controller/helper reliance on global business roles on `users`.
- **Acceptance checks:**
  - Authenticated controller actions can resolve venue context without ad hoc query logic.
  - Business role checks no longer rely on global user-role assumptions alone.
  - Cross-venue access is denied by server-side guards.

### A.3 Remove bootstrap-admin and public-signup assumptions
- **Status:** [ ]
- **Goal:** Replace internal-tool bootstrap logic with managed-service venue bootstrap.
- **Deliverables:**
  - Remove or disable public self-registration as the default commercial path.
  - Remove first-user-admin bootstrap logic from registration.
  - Introduce founder-managed venue bootstrap and owner/admin invitation flow.
  - Remove tests and helpers that encode first-user auto-admin behavior.
- **Acceptance checks:**
  - No fresh deployment grants privileged venue access through public signup.
  - Initial venue owner/admin creation is explicit and controlled.
  - Documentation and tests reflect the new bootstrap flow.

### 1.2 Mandatory profile completion gate
- **Status:** [x]
- **Goal:** Block operational app access until required profile fields are completed.
- **Completion notes:**
  - `ProfilesController` and profile gate helpers are implemented.
  - Incomplete users are redirected to profile completion.

### 1.3 Role-based authorization helpers
- **Status:** [x]
- **Goal:** Provide reusable authorization helpers.
- **Note:** Current helpers still need migration away from `users.user_role` toward `venue_memberships`.

### 1.1 First-user bootstrap admin
- **Status:** [!]
- **Goal:** Historical/superseded context only.
- **Reason:** This slice reflected the earlier internal-tool model and should be removed/replaced by A.3.

## Primary Files

- `Application/Helper/Controller.hs`
- `Web/Controller/Sessions.hs`
- `Web/Controller/Users.hs`
- `Web/Controller/Prelude.hs`
- `Web/FrontController.hs`
- `Web/Types.hs`
- `Test/SchemaSpec.hs`
- future controller tests under `Test/Controller/`

## Acceptance Focus

- venue-membership role restrictions
- public signup cannot create privileged venue access
- global `users` fields cannot bypass venue membership checks
