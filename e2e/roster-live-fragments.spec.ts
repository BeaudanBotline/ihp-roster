import { test, expect } from '@playwright/test';
import { gotoWhenReady } from './test-helpers';

async function loginAndOpenRoster(page) {
    await gotoWhenReady(page, '/NewSession', '#email');
    await page.fill('#email', 'e2e-test@example.com');
    await page.fill('#password', 'test-password-123');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL(/(RosterWeeks|ShowRosterWeek)/, { timeout: 60000 });
    await expect(page.locator('#roster-content')).toBeVisible({ timeout: 60000 });
}

async function selectStaffForRow(page, rowIndex, staffId) {
    const row = page.locator('tr[data-roster-row]').nth(rowIndex);
    const select = row.locator('select[name="staffId"]');
    await select.selectOption(staffId);
    await expect(select).toHaveValue(staffId);
}

async function normalizeLiveFragmentRoster(page) {
    const alphaCrewStaffId = 'a1000000-0000-0000-0000-000000000031';
    const managerEntry = page
        .locator('#roster-staff-panel-fragment .roster-staff-panel-entry')
        .filter({ hasText: 'E2E Manager' })
        .first();

    let rowCount = await page.locator('tr[data-roster-row]').count();
    while (rowCount > 1) {
        await page.locator('[data-roster-day-remove="true"]').first().click();
        rowCount -= 1;
        await expect(page.locator('tr[data-roster-row]')).toHaveCount(rowCount);
    }

    await selectStaffForRow(page, 0, alphaCrewStaffId);
    await expect(managerEntry).toContainText('0');
}

test.describe('Roster live fragments', () => {
    test('updates another viewer live after a slot assignment changes', async ({ browser }) => {
        const actorContext = await browser.newContext();
        const viewerContext = await browser.newContext();
        const actorPage = await actorContext.newPage();
        const viewerPage = await viewerContext.newPage();

        await loginAndOpenRoster(actorPage);
        await normalizeLiveFragmentRoster(actorPage);
        await loginAndOpenRoster(viewerPage);

        const actorManagerEntry = actorPage
            .locator('#roster-staff-panel-fragment .roster-staff-panel-entry')
            .filter({ hasText: 'E2E Manager' })
            .first();
        const viewerManagerEntry = viewerPage
            .locator('#roster-staff-panel-fragment .roster-staff-panel-entry')
            .filter({ hasText: 'E2E Manager' })
            .first();

        await expect(actorManagerEntry).toContainText('0');
        await expect(viewerManagerEntry).toContainText('0');

        const assignmentSelect = actorPage.locator('select[name="staffId"]').first();
        await assignmentSelect.selectOption('a0000000-0000-0000-0000-000000000101');

        await expect(actorManagerEntry).toContainText('1');
        await expect(viewerManagerEntry).toContainText('1');

        await actorContext.close();
        await viewerContext.close();
    });
});
