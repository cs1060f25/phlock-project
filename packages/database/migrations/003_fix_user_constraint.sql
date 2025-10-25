-- Fix users table constraint to allow platform-authenticated users
-- Apple Music doesn't provide email, so we need to allow users with only platform authentication

-- Drop the old constraint that requires email or phone
ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_check;

-- Add new constraint: Allow users with platform authentication to skip email/phone
-- Traditional signup users would need email or phone, but platform auth users don't
ALTER TABLE public.users
ADD CONSTRAINT users_check
CHECK (
  phone IS NOT NULL
  OR email IS NOT NULL
  OR platform_type IS NOT NULL
);
