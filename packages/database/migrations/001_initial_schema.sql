-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone TEXT UNIQUE,
  email TEXT UNIQUE,
  display_name TEXT NOT NULL,
  profile_photo_url TEXT,
  bio TEXT,
  privacy_who_can_send TEXT DEFAULT 'friends' CHECK (privacy_who_can_send IN ('everyone', 'friends', 'specific')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure at least one contact method exists
  CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

-- Create friendships table
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id_1 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_id_2 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure users can't friend themselves
  CHECK (user_id_1 != user_id_2),

  -- Ensure unique friendship pairs (regardless of order)
  UNIQUE(user_id_1, user_id_2)
);

-- Create indexes for performance
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_friendships_user1 ON friendships(user_id_1);
CREATE INDEX idx_friendships_user2 ON friendships(user_id_2);
CREATE INDEX idx_friendships_status ON friendships(status);
CREATE INDEX idx_friendships_created_at ON friendships(created_at);

-- Row Level Security (RLS) Policies

-- Enable RLS on tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Users table policies
-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can view profiles of their friends
CREATE POLICY "Users can view friends' profiles"
  ON users FOR SELECT
  USING (
    id IN (
      SELECT user_id_2 FROM friendships
      WHERE user_id_1 = auth.uid() AND status = 'accepted'
      UNION
      SELECT user_id_1 FROM friendships
      WHERE user_id_2 = auth.uid() AND status = 'accepted'
    )
  );

-- Friendships table policies
-- Users can view their own friendships
CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- Users can create friendships (send friend requests)
CREATE POLICY "Users can create friendships"
  ON friendships FOR INSERT
  WITH CHECK (user_id_1 = auth.uid());

-- Users can update friendships they're part of (accept/reject requests)
CREATE POLICY "Users can update own friendships"
  ON friendships FOR UPDATE
  USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- Users can delete friendships they're part of (unfriend)
CREATE POLICY "Users can delete own friendships"
  ON friendships FOR DELETE
  USING (user_id_1 = auth.uid() OR user_id_2 = auth.uid());

-- Helper function to get friendship status between two users
CREATE OR REPLACE FUNCTION get_friendship_status(user_a UUID, user_b UUID)
RETURNS TEXT AS $$
  SELECT status FROM friendships
  WHERE (user_id_1 = user_a AND user_id_2 = user_b)
     OR (user_id_1 = user_b AND user_id_2 = user_a)
  LIMIT 1;
$$ LANGUAGE SQL STABLE;

-- Helper function to check if two users are friends
CREATE OR REPLACE FUNCTION are_friends(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM friendships
    WHERE ((user_id_1 = user_a AND user_id_2 = user_b)
       OR (user_id_1 = user_b AND user_id_2 = user_a))
      AND status = 'accepted'
  );
$$ LANGUAGE SQL STABLE;
