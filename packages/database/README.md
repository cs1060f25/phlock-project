# Phlock Database

Supabase database schema and migrations for Phlock.

## Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note your project URL and anon key
4. Add them to `apps/mobile/.env`:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### 2. Run Migrations

In your Supabase project dashboard:

1. Go to **SQL Editor**
2. Copy contents of `migrations/001_initial_schema.sql`
3. Run the SQL
4. Verify tables and policies were created

Alternatively, use Supabase CLI:

```bash
# Install Supabase CLI
npm install -g supabase

# Link to your project
supabase link --project-ref your-project-ref

# Run migrations
supabase db push
```

## Database Schema

### Tables

#### `users`
User profiles and authentication data.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key, matches Supabase Auth user ID |
| `phone` | TEXT | Phone number (unique) |
| `email` | TEXT | Email address (unique) |
| `display_name` | TEXT | User's display name |
| `profile_photo_url` | TEXT | URL to profile photo |
| `bio` | TEXT | User bio/description |
| `privacy_who_can_send` | TEXT | Privacy setting: 'everyone', 'friends', 'specific' |
| `created_at` | TIMESTAMP | Account creation timestamp |

#### `friendships`
Friend connections between users.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id_1` | UUID | First user (requester) |
| `user_id_2` | UUID | Second user (recipient) |
| `status` | TEXT | 'pending', 'accepted', 'blocked' |
| `created_at` | TIMESTAMP | Friendship request timestamp |

### Row Level Security (RLS)

All tables have RLS enabled with the following policies:

**Users:**
- Users can view their own profile
- Users can update their own profile
- Users can view profiles of accepted friends

**Friendships:**
- Users can view friendships they're part of
- Users can create friend requests
- Users can accept/reject requests they receive
- Users can delete (unfriend) their own friendships

### Helper Functions

#### `get_friendship_status(user_a UUID, user_b UUID)`
Returns the friendship status between two users.

#### `are_friends(user_a UUID, user_b UUID)`
Returns TRUE if two users are friends (status = 'accepted').

## Next Migrations

Future schema additions:

- `shares` table (Phase 1.2)
- `crate_entries` table (Phase 1.3)
- `engagements` table (Phase 2)
- `phlocks` table (Phase 3)
- `influence_scores` table (Phase 4)
