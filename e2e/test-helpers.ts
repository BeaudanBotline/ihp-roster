import { expect, Page } from '@playwright/test';

export async function gotoWhenReady(page: Page, path: string, readySelector: string, timeoutMs = 60000) {
    const deadline = Date.now() + timeoutMs;
    let lastBodyText = '';

    while (Date.now() < deadline) {
        await page.goto(path);

        try {
            await page.locator(readySelector).waitFor({ state: 'visible', timeout: 2000 });
            return;
        } catch {
            lastBodyText = (await page.locator('body').textContent().catch(() => '')) ?? '';

            if (!lastBodyText.includes('Is compiling')) {
                break;
            }
        }

        await page.waitForTimeout(1000);
    }

    await expect(page.locator(readySelector), lastBodyText).toBeVisible({ timeout: 5000 });
}
