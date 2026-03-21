import { test, expect } from '@playwright/test';
import { gotoWhenReady } from './test-helpers';

async function login(page) {
    await gotoWhenReady(page, '/NewSession', '#email');
    await page.fill('#email', 'e2e-test@example.com');
    await page.fill('#password', 'test-password-123');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/(RosterWeeks|ShowRosterWeek)/, { timeout: 60000 });
    await expect(page.locator('#roster-week-shell')).toBeVisible();
}

test.describe('HTMX submit regressions', () => {
    test('leave request submit creates one request', async ({ page }) => {
        const note = 'single-submit-leave-check';

        await login(page);
        await gotoWhenReady(page, '/LeaveRequests', '#leave-requests-content');

        await page.getByRole('link', { name: 'New Request' }).click();
        await expect(page.locator('#leave-request-form')).toBeVisible();
        await page.fill('#startDate', '2026-03-21');
        await page.fill('#endDate', '2026-03-22');
        await page.fill('#notes', note);
        await page.getByRole('button', { name: 'Save' }).click();

        await expect(page.locator('#dialog-overlay-mount')).toBeEmpty();
        await expect(page.locator('#leave-requests-content')).toContainText(note);
        await expect(page.locator(`#leave-requests-content tr:has-text("${note}")`)).toHaveCount(1);
    });

    test('timesheet submit creates one card', async ({ page }) => {
        const startTime = '10:15';
        const endTime = '14:15';
        const renderedRange = '10:15 AM - 2:15 PM';

        await login(page);
        await gotoWhenReady(page, '/Timesheets', '#timesheet-week-shell');

        await page.getByRole('link', { name: 'Add Timesheet' }).first().click();
        await expect(page.locator('#timesheet-entry-create-form')).toBeVisible();
        await page.selectOption('#staffId', { label: 'E2E Manager' });
        await page.locator('input[name="startTime"]').evaluate((input, value) => {
            (input as HTMLInputElement).value = value as string;
        }, startTime);
        await page.locator('input[name="endTime"]').evaluate((input, value) => {
            (input as HTMLInputElement).value = value as string;
        }, endTime);
        await page.getByRole('button', { name: 'Save' }).click();

        await expect(page.locator('#dialog-overlay-mount')).toBeEmpty();
        await expect(page.locator('#timesheet-day-section-0')).toContainText(renderedRange);
        await expect(
            page.locator(`#timesheet-day-section-0 .border.rounded:has-text("E2E Manager"):has-text("${renderedRange}")`)
        ).toHaveCount(1);
    });
});
