# E2E Testing — Agent Guide

## Running Tests

All commands require `direnv exec .` prefix (or an active direnv shell).

```bash
# Run all e2e tests (requires devenv up)
direnv exec . e2e

# Run a specific test file
direnv exec . e2e e2e/auth.spec.ts

# Run in headed mode (visible browser)
direnv exec . e2e --headed

# Run with Playwright UI
direnv exec . e2e --ui

# Take a screenshot of a page
direnv exec . screenshot http://localhost:8000/Dashboard dash.png

# View the last test report
direnv exec . e2e-report
```

## Prerequisites

- `devenv up` must be running (provides the app server on `:8000` and the database)
- `make db` must have been run at least once (so the database schema exists)
- Test data is seeded automatically via `global-setup.ts` before tests run

## Writing New Tests

### File naming
Place test files in `e2e/` with the `.spec.ts` extension:
```
e2e/my-feature.spec.ts
```

### Basic template
```typescript
import { test, expect } from '@playwright/test';

test.describe('My Feature', () => {
    test('does something', async ({ page }) => {
        await page.goto('/MyPage');
        await expect(page.locator('body')).toContainText('Expected text');
    });
});
```

### Logging in within a test
```typescript
test('authenticated feature', async ({ page }) => {
    // Login with the seeded test user
    await page.goto('/NewSession');
    await page.fill('#email', 'e2e-test@example.com');
    await page.fill('#password', 'test-password-123');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/Dashboard/);

    // Now navigate to the authenticated page
    await page.goto('/MyProtectedPage');
    // ...assertions...
});
```

## Test Data Convention

- All e2e test data uses the **`e2e-` prefix** on emails and identifiers
- The seeded test user is `e2e-test@example.com` with password `test-password-123`
- `global-teardown.ts` deletes all users with `email LIKE 'e2e-%'` after tests complete
- To add more fixture data, add SQL to `e2e/fixtures/seed.sql` using the `e2e-` prefix
- Use `ON CONFLICT DO UPDATE` for idempotency

## Common Selectors for IHP/Bootstrap Forms

| Element | Selector |
|---------|----------|
| Submit button | `button[type="submit"]` |
| Flash message | `.alert` |
| Flash success | `.alert-success` |
| Flash error | `.alert-danger` |
| Navigation link | `a:has-text("Link Text")` |
| Delete/logout button | `.js-delete` or `a:has-text("Logout")` |

### Form field selectors

**Manually-specified IDs** (login form `Sessions/New.hs`):

| Field | Selector |
|-------|----------|
| Email | `#email` |
| Password | `#password` |

**`formFor`-generated IDs** follow the pattern `modelName_fieldName` (camelCase). For example, `formFor @User` with `textField #email` renders `id="user_email"`. Prefer selecting by `name` attribute to avoid ambiguity when multiple fields share a model:

| Field | Selector |
|-------|----------|
| Email (Users form) | `[name="email"]` |
| Password (Users form) | `[name="passwordHash"]` |
| Confirm password | `[name="passwordConfirmation"]` |

## Debugging

```bash
# Run with debug logging
DEBUG=pw:api direnv exec . e2e

# Run headed + slow motion
direnv exec . e2e --headed --slow-mo=500

# Generate and open a trace
direnv exec . e2e --trace on
npx playwright show-trace test-results/*/trace.zip
```
