-- =====================================================
-- LINK EXISTING USERS TO SUPABASE AUTH
-- =====================================================
-- This script creates Supabase Auth accounts for existing custom users
-- and links them via the auth_user_id column.
--
-- Purpose: One-time migration to link existing users to auth system
-- =====================================================

-- Create Supabase Auth user for "woon" (jam0705@gmail.com)
-- Note: You'll need to run this as a Supabase admin since we're directly inserting into auth.users

DO $$
DECLARE
  v_user_id UUID := 'b1660762-c5ca-4389-9461-72d505e52ebb'; -- woon's custom user ID
  v_user_email TEXT := 'jam0705@gmail.com';
  v_auth_user_id UUID;
  v_encrypted_password TEXT;
BEGIN
  -- Generate a random UUID for the auth user ID
  v_auth_user_id := gen_random_uuid();

  -- Generate a random password hash (user won't need to know this)
  -- They'll authenticate via Spotify/Apple Music OAuth
  v_encrypted_password := crypt(gen_random_uuid()::text, gen_salt('bf'));

  -- Insert into auth.users table
  -- Note: This requires admin/service role access
  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    confirmation_token,
    aud,
    role
  ) VALUES (
    v_auth_user_id,
    '00000000-0000-0000-0000-000000000000', -- Default instance ID
    v_user_email,
    v_encrypted_password,
    NOW(), -- Confirm email immediately
    NOW(),
    NOW(),
    '',
    'authenticated',
    'authenticated'
  )
  ON CONFLICT (email) DO NOTHING; -- Skip if email already exists

  -- If auth user was created, update the custom user record to link it
  UPDATE users
  SET auth_user_id = v_auth_user_id
  WHERE id = v_user_id;

  -- Also need to insert into auth.identities table
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_auth_user_id,
    jsonb_build_object(
      'sub', v_auth_user_id::text,
      'email', v_user_email
    ),
    'email',
    NOW(),
    NOW(),
    NOW()
  )
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'Successfully linked user % (%) to auth user %', v_user_email, v_user_id, v_auth_user_id;

EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error linking user: %', SQLERRM;
END $$;

-- =====================================================
-- SIMPLER ALTERNATIVE: Use Supabase Auth Admin API
-- =====================================================
-- If the above doesn't work due to permissions, run this query
-- to get the user info, then use the Supabase Auth Admin API
-- or the app's sign-in flow to create the auth account:

SELECT
  id,
  email,
  display_name,
  'User needs to sign in again via app to create Supabase Auth link' as action
FROM users
WHERE auth_user_id IS NULL;

-- After running the migration and this script:
-- 1. User "woon" should sign in via the app again
-- 2. The app will automatically create a Supabase Auth account
-- 3. RLS policies will start working
