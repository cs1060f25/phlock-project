# Supabase Auth Integration Guide

This guide walks you through migrating from platform-only OAuth to production-grade Supabase Auth with proper RLS security.

## Overview

**Current Architecture (Insecure)**:
- Direct Spotify/Apple OAuth → Manual user creation → UserDefaults storage
- RLS policies disabled (anyone can access/modify data)
- No session management

**New Architecture (Production-Ready)**:
- Supabase OAuth → auth.users + users table linking → Supabase session management
- Proper RLS policies using auth.uid()
- Defense-in-depth security

## Step 1: Apply Database Migrations

### Option A: Using Supabase CLI (Recommended)

```bash
cd /Users/woonlee/Desktop/Phlock/phlock-dev

# Link to your remote Supabase project (if not already linked)
supabase link --project-ref szfxnzsapojuemltjghb

# Push migrations to remote database
supabase db push

# Alternatively, if you have local Supabase running:
supabase db reset  # Resets and applies all migrations
```

### Option B: Manual Application via Supabase Dashboard

1. Go to https://supabase.com/dashboard/project/szfxnzsapojuemltjghb
2. Navigate to **SQL Editor**
3. Apply migrations in order:
   - `packages/database/migrations/006_integrate_supabase_auth.sql`
   - `supabase/migrations/20251029010000_fix_rls_with_auth_integration.sql` (if not already applied)

## Step 2: Configure OAuth Providers in Supabase Dashboard

### 2A: Configure Spotify OAuth

1. Go to **Authentication** → **Providers** in Supabase Dashboard
2. Find **Spotify** and click to configure
3. Enable the provider
4. Enter your Spotify credentials:
   - **Client ID**: `68032dd9c4774f2b8f16ced8c77c9d25` (from Config.swift)
   - **Client Secret**: Get from https://developer.spotify.com/dashboard
5. Add **Redirect URLs**:
   - `https://szfxnzsapojuemltjghb.supabase.co/auth/v1/callback`
   - For local testing: `http://localhost:54321/auth/v1/callback`
6. Go to Spotify Developer Dashboard and add these redirect URIs to your app
7. Click **Save**

**Important Scopes**: Supabase will request these automatically:
- `user-read-email`
- `user-read-private`

For additional music data access, you'll need to request extra scopes in your app code (see AuthService).

### 2B: Configure Sign in with Apple

1. Go to **Authentication** → **Providers** in Supabase Dashboard
2. Find **Apple** and click to configure
3. Enable the provider
4. Create Apple Service ID:
   - Go to https://developer.apple.com/account/resources/identifiers/list/serviceId
   - Click **+** to create new identifier
   - Select **Services IDs**, click **Continue**
   - Description: "Phlock Sign in with Apple"
   - Identifier: `com.phlock.signin` (or your bundle ID + `.signin`)
   - Enable **Sign in with Apple**
   - Configure domains and return URLs:
     - Domains: `szfxnzsapojuemltjghb.supabase.co`
     - Return URL: `https://szfxnzsapojuemltjghb.supabase.co/auth/v1/callback`
5. Back in Supabase Dashboard, enter:
   - **Services ID**: Your Service ID (e.g., `com.phlock.signin`)
   - **Key ID**: From your Apple Developer Portal
   - **Team ID**: Your Apple Team ID (Y23RJZMV5M based on JWT token)
   - **Private Key**: Copy from your .p8 key file
6. Click **Save**

### 2C: Update Redirect URLs in App

Add these to your app's URL schemes (Info.plist):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.phlock.app</string>
        </array>
    </dict>
</array>
```

## Step 3: Account Linking Strategy

The new AuthService handles three scenarios:

**Scenario 1: Accidental duplicate account**
- User signs up with Spotify → Later taps "Sign in with Apple" by accident
- **Solution**: Email-based linking detects existing account, links providers

**Scenario 2: Wrong provider selection**
- User wants Spotify music but taps Apple OAuth button
- **Solution**: After auth, prompt to connect Spotify for music access

**Scenario 3: Legitimate platform switch**
- User started with Spotify, now wants Apple Music
- **Solution**: Allow platform switching in settings

## Step 4: Update iOS App Code

The new AuthService (see `/apps/ios/phlock/phlock/Services/AuthService.swift`) implements:

1. **Supabase OAuth Sign In**:
   ```swift
   func signInWithSpotify() async throws -> User
   func signInWithApple() async throws -> User
   ```

2. **Account Linking**:
   - Checks email for existing accounts
   - Links multiple OAuth providers
   - Tracks auth_provider and music_platform separately

3. **Session Management**:
   - Uses Supabase sessions (not UserDefaults)
   - Proper token refresh
   - Session persistence

4. **Music Platform Handling**:
   - Spotify: OAuth provides both auth + music access
   - Apple Music: OAuth for auth, MusicKit for music access

## Step 5: Migration Strategy for Existing Users

For users created before this migration:

```sql
-- Run this to link existing test users to auth.users
-- This is handled automatically in app code during first sign-in with new system
```

The app will:
1. Detect user without `auth_user_id` on sign-in
2. Prompt for OAuth (Spotify or Apple)
3. Link the OAuth account to existing user record via email

## Step 6: Testing Checklist

- [ ] Apply all migrations successfully
- [ ] Configure Spotify OAuth in Supabase Dashboard
- [ ] Configure Apple OAuth in Supabase Dashboard
- [ ] Test Spotify sign-in flow
- [ ] Test Apple sign-in flow
- [ ] Test account linking (sign in with different provider using same email)
- [ ] Verify RLS works: shares data loads correctly
- [ ] Verify sessions persist across app restarts
- [ ] Test token refresh
- [ ] Test sign out

## Step 7: Verify RLS is Working

Run these queries in Supabase SQL Editor:

```sql
-- Should return your user ID when signed in
SELECT get_current_user_id();

-- Should return only your shares (sender or recipient)
SELECT * FROM shares WHERE sender_id = get_current_user_id() OR recipient_id = get_current_user_id();

-- Should return NULL when not authenticated
-- (Run this in an incognito window)
SELECT auth.uid();
```

## Rollback Plan

If something goes wrong:

```sql
-- Re-enable permissive policy (temporary only!)
CREATE POLICY "Temp allow all for debugging"
ON public.shares FOR ALL TO anon, authenticated
USING (true)
WITH CHECK (true);
```

Then investigate and fix the auth integration before removing this policy.

## Security Notes

1. **Never commit real OAuth secrets** to git
2. **Use environment-specific configs** for dev/staging/prod
3. **Rotate secrets** if they're exposed
4. **Enable MFA** on your Supabase and OAuth provider accounts
5. **Monitor auth logs** for suspicious activity
6. **Set up rate limiting** in Supabase Dashboard

## Next Steps

After successful migration:
1. Remove old dummy data that doesn't have auth_user_id
2. Update other services to use `get_current_user_id()` function
3. Add more granular RLS policies as needed
4. Implement proper error handling for auth failures
5. Add user profile linking UI in settings
