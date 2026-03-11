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

async function ensureSecondRosterRow(page) {
    const rows = page.locator('tr[data-roster-row]');
    if (await rows.count() >= 2) return;

    await page.locator('[data-roster-day-add="true"]').first().click();
    await expect(rows).toHaveCount(2);
}

async function assignStaffToRow(page, rowIndex, staffId) {
    const row = page.locator('tr[data-roster-row]').nth(rowIndex);
    const select = row.locator('select[name="staffId"]');
    await select.selectOption(staffId);
    await expect(select).toHaveValue(staffId);
}

async function normalizeRosterForDuplicateConflict(actorPage) {
    const alphaCrewStaffId = 'a1000000-0000-0000-0000-000000000031';
    const actorManagerEntry = actorPage
        .locator('#roster-staff-panel-fragment .roster-staff-panel-entry')
        .filter({ hasText: 'E2E Manager' })
        .first();

    await ensureSecondRosterRow(actorPage);
    await assignStaffToRow(actorPage, 0, alphaCrewStaffId);
    await assignStaffToRow(actorPage, 1, '');
    await expect(actorManagerEntry).toContainText('0');
}

function duplicateConflictCells(page) {
    return page.locator('.slot-staff-cell.conflict-critical');
}

test.describe('Roster duplicate conflicts', () => {
    test.describe.configure({ retries: 0 });

    test('actor and viewer both keep duplicate conflict highlighting without breaking the roster grid', async ({ browser }) => {
        const actorContext = await browser.newContext();
        const viewerContext = await browser.newContext();
        const actorPage = await actorContext.newPage();
        const viewerPage = await viewerContext.newPage();

        await loginAndOpenRoster(actorPage);
        await normalizeRosterForDuplicateConflict(actorPage);

        await loginAndOpenRoster(viewerPage);
        await expect(viewerPage.locator('tr[data-roster-row]')).toHaveCount(2);

        const managerStaffId = 'a0000000-0000-0000-0000-000000000101';
        const actorManagerEntry = actorPage
            .locator('#roster-staff-panel-fragment .roster-staff-panel-entry')
            .filter({ hasText: 'E2E Manager' })
            .first();

        await assignStaffToRow(actorPage, 0, managerStaffId);
        await expect(actorManagerEntry).toContainText('1');
        await assignStaffToRow(actorPage, 1, managerStaffId);
        await expect(actorManagerEntry).toContainText('2');

        await expect(duplicateConflictCells(actorPage)).toHaveCount(2);
        await expect(duplicateConflictCells(viewerPage)).toHaveCount(2);

        const viewerGridState = await viewerPage.locator('table.roster-grid').evaluate((table) => {
            const bodyRows = Array.from(table.querySelectorAll('tbody > tr[data-roster-row]'));
            const outsideRows = Array.from(document.querySelectorAll('tr[data-roster-row]')).filter(
                (row) => !row.closest('tbody'),
            );
            return {
                bodyRowCount: bodyRows.length,
                outsideRowCount: outsideRows.length,
                firstRowCellCount: bodyRows[0]?.children.length ?? 0,
                secondRowCellCount: bodyRows[1]?.children.length ?? 0,
                selectCount: table.querySelectorAll('select[name="staffId"]').length,
                visibleSelectCount: bodyRows.filter((row) => row.querySelector('select[name="staffId"]')).length,
            };
        });

        expect(viewerGridState).toEqual({
            bodyRowCount: 2,
            outsideRowCount: 0,
            firstRowCellCount: 4,
            secondRowCellCount: 3,
            selectCount: 2,
            visibleSelectCount: 2,
        });

        await actorContext.close();
        await viewerContext.close();
    });
});
