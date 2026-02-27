import { execSync } from 'child_process';
import path from 'path';

export default function globalTeardown() {
    const projectRoot = path.resolve(__dirname, '..');
    const dbSocket = path.join(projectRoot, 'build', 'db');

    console.log('E2E teardown: cleaning test data...');
    execSync(
        `psql -h "${dbSocket}" app -c "DELETE FROM users WHERE email LIKE 'e2e-%'"`,
        { stdio: 'inherit' },
    );
    console.log('E2E teardown: done.');
}
