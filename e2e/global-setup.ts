import { execSync } from 'child_process';
import path from 'path';

export default function globalSetup() {
    const projectRoot = path.resolve(__dirname, '..');
    const dbSocket = path.join(projectRoot, 'build', 'db');
    const seedFile = path.join(__dirname, 'fixtures', 'seed.sql');

    console.log('E2E setup: seeding test data...');
    execSync(`psql -h "${dbSocket}" app -f "${seedFile}"`, {
        stdio: 'inherit',
    });
    console.log('E2E setup: done.');
}
