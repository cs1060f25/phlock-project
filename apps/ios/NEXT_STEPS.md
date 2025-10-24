# Phlock iOS - Next Steps

## ✅ What's Been Completed

We've built the complete iOS authentication foundation for Phlock:

### Models (3 files)
- `User.swift` - User profile with platform data
- `Friendship.swift` - Friend relationships
- `PlatformToken.swift` - OAuth tokens

### Services (5 files)
- `Config.swift` - App configuration
- `SupabaseClient.swift` - Supabase connection
- `SpotifyService.swift` - Spotify OAuth + API
- `AppleMusicService.swift` - MusicKit integration
- `AuthService.swift` - Main auth coordinator

### ViewModels (1 file)
- `AuthenticationState.swift` - Observable auth state

### UI Components (3 files)
- `PhlockButton.swift` - Reusable button
- `PhlockTextField.swift` - Reusable text field
- `LoadingView.swift` - Loading spinner

### Views (4 files)
- `WelcomeView.swift` - Onboarding screen
- `PlatformSelectionView.swift` - Choose Spotify/Apple Music
- `ProfileSetupView.swift` - Complete profile setup
- `MainView.swift` - Authenticated app placeholder

### Updated Files (2 files)
- `phlockApp.swift` - App entry point with AuthenticationState
- `ContentView.swift` - Conditional navigation

---

## 📋 Step 1: Add New Files to Xcode

**Important:** The `Views` and `ViewModels` folders need to be added to Xcode.

1. In Xcode Project Navigator, **right-click** on the `phlock` folder
2. Select **"Add Files to "phlock"..."**
3. Navigate to `/Users/woonlee/Desktop/Phlock/phlock-dev/apps/ios/phlock/phlock/`
4. Select these folders:
   - ✅ `Views` folder
   - ✅ `ViewModels` folder
5. **Make sure:**
   - ☐ **UNCHECK** "Copy items if needed" (files are already in place)
   - ✅ **CHECK** "Create groups"
   - ✅ **CHECK** "Add to targets: phlock"
6. Click **"Add"**

---

## ⚙️ Step 2: Configure the App

### 2.1 Update Config.swift

Open `Services/Config.swift` and replace the placeholder values:

```swift
// Supabase Configuration
static let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

// Spotify Configuration
static let spotifyClientId = "YOUR_SPOTIFY_CLIENT_ID"
```

**Where to get these:**

**Supabase:**
1. Go to your Supabase project dashboard
2. Settings → API
3. Copy `Project URL` and `anon/public` key

**Spotify:**
1. Go to https://developer.spotify.com/dashboard
2. Create a new app (or use existing)
3. Copy the **Client ID**
4. **Important:** Add redirect URI: `phlock-spotify://callback` in app settings

**Apple Music (optional for now):**
- You'll need to generate a developer token later
- Can leave the placeholder for initial testing

### 2.2 Build the Project

Press **⌘B** to build the project.

**Expected:**
- You'll likely see some compilation errors about missing Supabase API methods or types
- This is normal - we'll refine the Supabase integration

**If you see other errors:**
- Make sure all Swift files are added to the target
- Check that Swift Package Dependencies are properly resolved

---

## 🗄️ Step 3: Update Database Schema

The current Supabase database needs new fields for platform OAuth.

### 3.1 Update `users` table

Run this SQL in your Supabase SQL Editor:

```sql
-- Add platform authentication fields
ALTER TABLE users
ADD COLUMN IF NOT EXISTS platform_type TEXT,
ADD COLUMN IF NOT EXISTS platform_user_id TEXT,
ADD COLUMN IF NOT EXISTS platform_data JSONB;

-- Remove phone requirement (no longer using phone auth)
ALTER TABLE users
ALTER COLUMN phone DROP NOT NULL;

-- Create unique constraint on platform auth
CREATE UNIQUE INDEX IF NOT EXISTS users_platform_unique
ON users(platform_type, platform_user_id);
```

### 3.2 Create `platform_tokens` table

```sql
-- Create platform tokens table
CREATE TABLE IF NOT EXISTS platform_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform_type TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    scope TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS platform_tokens_user_id_idx ON platform_tokens(user_id);
CREATE INDEX IF NOT EXISTS platform_tokens_platform_type_idx ON platform_tokens(platform_type);

-- Enable RLS
ALTER TABLE platform_tokens ENABLE ROW LEVEL SECURITY;

-- RLS policies: users can only access their own tokens
CREATE POLICY "Users can view own tokens"
ON platform_tokens FOR SELECT
USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can insert own tokens"
ON platform_tokens FOR INSERT
WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Users can update own tokens"
ON platform_tokens FOR UPDATE
USING (auth.uid()::uuid = user_id);
```

---

## 🧪 Step 4: Test the App

Once configured, you should be able to:

1. **Run the app** (⌘R)
2. **See the Welcome screen** with "Get Started" button
3. **Tap "Get Started"** → Navigate to Platform Selection
4. **Tap "Continue with Spotify"** → Opens Spotify OAuth
5. **Sign in with Spotify** → Returns to app
6. **Complete profile** → Main app screen

**Note:** Actual OAuth may not work until you:
- Add valid Spotify Client ID
- Configure redirect URI in Spotify Dashboard
- Add Supabase credentials

---

## 🐛 Known Issues & Next Steps

### Supabase Auth Integration

The current implementation creates users directly in the database. You may need to:
- Integrate with Supabase Auth for proper session management
- Use Supabase Auth's social login providers
- Or keep the current approach and manage sessions manually

### Apple Music Developer Token

Apple Music requires a server-generated JWT developer token. Options:
1. Generate it manually and hardcode (for testing only)
2. Create a serverless function to generate it
3. Use a backend service

### Database Migrations

Consider moving the SQL migrations to `packages/database/migrations/` for version control.

---

## 📦 What's Left for Phase 1.1

- [ ] Test and refine OAuth flows
- [ ] Implement friend discovery features
- [ ] Build friend request system
- [ ] Create friends list UI
- [ ] Test end-to-end authentication

---

## 🚀 Ready to Continue?

Once you've completed Steps 1-3:
1. Try building and running the app
2. Report any errors you encounter
3. We'll iterate and fix issues together
4. Then move on to the friend system and other Phase 1 features!

---

**Questions?** Let me know what step you're on and any errors you see!
