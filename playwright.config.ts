import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: './e2e',
    fullyParallel: false,
    workers: 1,
    retries: 1,
    reporter: 'html',

    globalSetup: './e2e/global-setup.ts',
    globalTeardown: './e2e/global-teardown.ts',

    use: {
        baseURL: 'http://localhost:8000',
        screenshot: 'only-on-failure',
        trace: 'on-first-retry',
    },

    projects: [
        {
            name: 'chromium',
            use: { browserName: 'chromium' },
        },
    ],
});
