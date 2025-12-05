-- Remove the auto_follow_woon trigger so we can control when it happens from the app
-- The auto-follow will now be triggered from Swift after onboarding completion

DROP TRIGGER IF EXISTS auto_follow_woon_trigger ON users;
DROP FUNCTION IF EXISTS auto_follow_woon();
