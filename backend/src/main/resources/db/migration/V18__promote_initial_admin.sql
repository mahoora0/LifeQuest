-- The initial production administrator is created through the normal signup
-- flow so its password is encoded by the application. This migration only
-- grants the account the authorization required by the admin console.
UPDATE users
SET role = 'ADMIN',
    updated_at = CURRENT_TIMESTAMP(6)
WHERE email = 'admin@lifequest.kr';
