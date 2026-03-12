import { test, expect } from '@playwright/test';

async function loginAndOpenRoster(page) {
    await page.goto('/NewSession');
    await page.fill('#email', 'e2e-test@example.com');
    await page.fill('#password', 'test-password-123');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL(/(RosterWeeks|ShowRosterWeek)/);

    const createDraftButton = page.locator('button:has-text("Create Draft Roster")');
    if (await createDraftButton.isVisible()) {
        await createDraftButton.click();
    }

    await expect(page.locator('#roster-content')).toBeVisible();
    await expect(page.locator('.roster-staff-panel')).toBeVisible();
}

test.describe('Roster Staff Modal', () => {
    test('edits staff inline without navigating away from the roster', async ({ page }) => {
        await loginAndOpenRoster(page);

        const initialUrl = page.url();
        const modalMount = page.locator('#dialog-overlay-mount');
        const staffEntry = page.locator('.roster-staff-panel-entry').first();
        const nameLabel = staffEntry.locator('.roster-staff-name-primary');
        const originalName = (await nameLabel.textContent())?.trim() || 'E2E Manager';
        const updatedName = 'Roster Modal Spec';

        await staffEntry.getByRole('button', { name: 'Edit' }).click();

        await expect(page).toHaveURL(initialUrl);
        await expect(modalMount.locator('[data-dialog-overlay="true"]')).toBeVisible();
        await expect(modalMount).toContainText('Edit Staff Member');

        const firstNameField = modalMount.locator('#firstName');
        const lastNameField = modalMount.locator('#lastName');
        const formAction = await modalMount.locator('form').getAttribute('action');
        const weekOffset = await modalMount.locator('input[name="weekOffset"]').inputValue();

        const validationResponse = await page.evaluate(
            async ({ action, currentWeekOffset }) => {
                const response = await fetch(action, {
                    method: 'POST',
                    headers: {
                        'HX-Request': 'true',
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: new URLSearchParams({
                        weekOffset: currentWeekOffset,
                        firstName: '',
                        lastName: 'User',
                        idealShiftsPerWeek: '4',
                        isActive: 'on',
                    }).toString(),
                });

                return await response.text();
            },
            { action: formAction ?? '', currentWeekOffset: weekOffset },
        );

        expect(validationResponse).toContain('Edit Staff Member');
        expect(validationResponse).toContain('This field cannot be empty');
        expect(validationResponse).not.toContain('Roster App');

        await firstNameField.fill('Roster');
        await lastNameField.fill('Modal Spec');
        await modalMount.getByRole('button', { name: 'Save' }).click();

        await expect(page).toHaveURL(initialUrl);
        await expect(modalMount).toBeEmpty();
        const updatedEntry = page.locator('.roster-staff-panel-entry').filter({ hasText: updatedName }).first();
        await expect(updatedEntry.locator('.roster-staff-name-primary')).toHaveText(updatedName);

    });
});
