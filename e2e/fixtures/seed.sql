-- Seed data for e2e tests.
-- All test data uses the 'e2e-' prefix to avoid clobbering dev data.
-- Password for this user is: test-password-123
INSERT INTO users (id, email, password_hash, failed_login_attempts)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'e2e-test@example.com',
    'sha256|17|pTjl57yJOvFluR4n2l2OmA==|beKP33BwrGQhNd1xvMF0rt7EKxW1tR6KaN1i8ExJLzs=',
    0
)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    failed_login_attempts = EXCLUDED.failed_login_attempts,
    locked_at = NULL;
