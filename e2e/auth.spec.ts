import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
    test('login flow: sign in, view dashboard, logout', async ({ page }) => {
        // Navigate to login page
        await page.goto('/NewSession');
        await expect(page.locator('body')).toContainText('Sign In');

        // Fill in credentials
        await page.fill('#email', 'e2e-test@example.com');
        await page.fill('#password', 'test-password-123');
        await page.click('button[type="submit"]');

        // Should redirect to dashboard
        await expect(page).toHaveURL(/Dashboard/);
        await expect(page.locator('body')).toContainText('e2e-test@example.com');

        // Logout
        await page.click('a:has-text("Logout"), button:has-text("Logout")');

        // Should redirect to login page
        await expect(page).toHaveURL(/NewSession/);
    });

    test('dashboard requires authentication', async ({ page }) => {
        // Try to access dashboard without being logged in
        await page.goto('/Dashboard');

        // Should redirect to login page
        await expect(page).toHaveURL(/NewSession/);
    });

    test('login with wrong password shows error', async ({ page }) => {
        await page.goto('/NewSession');
        await page.fill('#email', 'e2e-test@example.com');
        await page.fill('#password', 'wrong-password');
        await page.click('button[type="submit"]');

        // Should stay on login page with error
        await expect(page).toHaveURL(/.*Session.*/);
        await expect(page.locator('body')).toContainText(/[Ii]nvalid/);
    });
});
