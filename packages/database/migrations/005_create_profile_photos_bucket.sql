-- Create storage bucket for profile photos

-- Insert bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete profile photos" ON storage.objects;

-- Set up RLS policy for profile photos bucket
-- Allow anyone to read (public bucket)
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

-- Allow authenticated and anon users to upload their own profile photo
CREATE POLICY "Users can upload profile photos"
ON storage.objects FOR INSERT
TO public
WITH CHECK (bucket_id = 'profile-photos');

-- Allow authenticated and anon users to update/replace their profile photo
CREATE POLICY "Users can update profile photos"
ON storage.objects FOR UPDATE
TO public
USING (bucket_id = 'profile-photos')
WITH CHECK (bucket_id = 'profile-photos');

-- Allow authenticated and anon users to delete their profile photo
CREATE POLICY "Users can delete profile photos"
ON storage.objects FOR DELETE
TO public
USING (bucket_id = 'profile-photos');
