-- Fix RLS policies to work with platform-based authentication
-- Since we're not using Supabase Auth (using Spotify/Apple Music OAuth instead),
-- we need to allow anon role to update/insert users

-- Drop the restrictive policies that require auth.uid()
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;

-- Keep the policy that allows anon to read all profiles (already exists from 002)
-- CREATE POLICY "Users can read all profiles"
-- ON public.users FOR SELECT TO anon, authenticated USING (true);

-- Allow anon users to update any user (for platform OAuth flow)
-- In production, you'd want to add server-side validation or use Supabase Auth with custom claims
CREATE POLICY "Allow platform auth updates"
ON public.users FOR UPDATE TO anon
USING (true)
WITH CHECK (true);

-- The insert policy from 002 already allows creation
-- CREATE POLICY "Allow user creation during signup"
-- ON public.users FOR INSERT TO anon WITH CHECK (true);
