# AuthService V2 Implementation Summary

## What Changed

I've created a production-ready authentication service (`AuthService_v2.swift`) that replaces the manual OAuth approach with proper Supabase Auth integration.

### Key Architectural Changes

**Old Approach (AuthService.swift)**:
- Direct Spotify/Apple OAuth → Manual user creation → UserDefaults storage
- Deterministic passwords to link to Supabase Auth as a workaround
- RLS disabled because `auth.uid()` returns NULL

**New Approach (AuthService_v2.swift)**:
- Supabase OAuth → auth.users auto-creation → Supabase session management
- Proper `auth.uid()` integration with RLS policies
- Email-based account linking for multi-provider support

## Core Features

### 1. Spotify Authentication
```swift
func signInWithSpotify() async throws -> User
```
- Uses `supabase.auth.signInWithOAuth(provider: .spotify)`
- Requests proper scopes for music data access
- Fetches music data from Spotify API using OAuth token
- Creates/updates user record with `auth_user_id` linked to `auth.uid()`
- Handles account linking if email already exists

### 2. Apple Sign In
```swift
func signInWithApple() async throws -> User
```
- Uses `supabase.auth.signInWithOAuth(provider: .apple)`
- Hybrid approach: Apple OAuth for auth + MusicKit for music data
- Handles account linking
- Supports music platform selection (Spotify vs Apple Music)

### 3. Account Linking Strategy
```swift
private func findAndLinkExistingUser(authUserId:email:provider:) async throws -> User?
```

Handles all three scenarios we discussed:
- **Scenario 1**: User signs up with Spotify, later uses Apple → Links accounts via email
- **Scenario 2**: User wants Spotify but uses Apple OAuth → Prompts to connect Spotify
- **Scenario 3**: Legitimate platform switch → Updates auth_provider to "both"

### 4. Session Management
```swift
var currentUser: User? { get async throws }
var currentUserId: UUID? { get async }
```
- Uses Supabase sessions (no UserDefaults!)
- Automatic token refresh
- Session state listener for auth events

## Integration Steps

### Step 1: Configure OAuth Providers

Follow `SUPABASE_AUTH_MIGRATION_GUIDE.md` to:
1. Configure Spotify OAuth in Supabase Dashboard
2. Configure Sign in with Apple in Supabase Dashboard
3. Apply database migrations

### Step 2: Update Info.plist

Add URL scheme for OAuth callback:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>phlock</string>
        </array>
    </dict>
</array>
```

### Step 3: Handle OAuth Callback

In your `@main` App file or SceneDelegate:

```swift
import Supabase

// Handle URL callback from OAuth
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    Task {
        try? await PhlockSupabaseClient.shared.client.auth.session(from: url)
    }
    return true
}

// For SwiftUI App:
struct PhlockApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    Task {
                        try? await PhlockSupabaseClient.shared.client.auth.session(from: url)
                    }
                }
        }
    }
}
```

### Step 4: Update View Code

Replace `AuthService.shared` with `AuthServiceV2.shared`:

**Before:**
```swift
let user = try await AuthService.shared.signInWithSpotify()
```

**After:**
```swift
let user = try await AuthServiceV2.shared.signInWithSpotify()
```

**Get Current User:**
```swift
// Old way (UserDefaults)
if let userId = UserDefaults.standard.string(forKey: "phlock_current_user_id") {
    // ...
}

// New way (Supabase session)
if let user = try await AuthServiceV2.shared.currentUser {
    print("Current user: \(user.displayName)")
}
```

### Step 5: Update Other Services

Update any services that use `UserDefaults` for user ID:

**Before:**
```swift
guard let userIdString = UserDefaults.standard.string(forKey: "phlock_current_user_id"),
      let userId = UUID(uuidString: userIdString) else {
    return
}
```

**After:**
```swift
guard let userId = await AuthServiceV2.shared.currentUserId else {
    return
}
```

### Step 6: Migration for Existing Users

Users created with old AuthService won't have `auth_user_id`. On first sign-in with V2:
1. They'll be prompted to authenticate with OAuth
2. Email-based linking will connect their existing user record
3. Their data will be preserved

## Testing Checklist

### OAuth Flow
- [ ] Spotify OAuth opens ASWebAuthenticationSession
- [ ] User authenticates successfully
- [ ] App receives callback at `phlock://auth-callback`
- [ ] User record created with `auth_user_id` populated
- [ ] Session persists across app restarts

### Account Linking
- [ ] Sign up with Spotify (email: test@example.com)
- [ ] Sign out
- [ ] Sign in with Apple (same email: test@example.com)
- [ ] Verify accounts linked (auth_provider = "both")
- [ ] Verify both OAuth providers work

### RLS Security
- [ ] Run: `SELECT get_current_user_id();` → Returns your user ID
- [ ] Run: `SELECT * FROM shares;` → Returns only your shares
- [ ] Sign out → Run same query → Returns nothing (RLS blocks)

### Music Platform Selection
- [ ] Sign in with Apple OAuth
- [ ] Prompted to select music platform
- [ ] If select Spotify → Prompted to connect Spotify
- [ ] If select Apple Music → MusicKit authorization requested

## Known Limitations

### 1. ASWebAuthenticationSession UX
Supabase OAuth uses `ASWebAuthenticationSession` which shows a modal browser. This is less seamless than native SDK flows but doesn't require backend infrastructure.

**Alternative**: Implement native OAuth with backend token exchange (requires server).

### 2. Apple Music Hybrid Flow
Apple users need two authorizations:
1. Sign in with Apple (authentication)
2. MusicKit (music data access)

This is unavoidable - Apple separates identity and music APIs.

### 3. Spotify Scope Refresh
If you need additional Spotify scopes later, users must re-authenticate. Store required scopes in config.

## Rollback Plan

If V2 has issues:
1. Revert to old AuthService: `git checkout AuthService.swift`
2. Or keep both: Use V2 for new users, V1 for existing users
3. Migration helper to move users from V1 to V2 gradually

## Security Improvements

✅ **Before (Insecure)**:
- RLS disabled - anyone can access data
- User IDs in UserDefaults (client-side only)
- No session management
- Deterministic passwords as workaround

✅ **After (Secure)**:
- RLS enabled with proper `auth.uid()` checks
- Server-side session management
- Automatic token refresh
- No password workarounds - proper OAuth flow
- Defense in depth

## Performance Considerations

- **Session Lookup**: Cached by Supabase SDK, minimal overhead
- **Token Refresh**: Automatic background refresh
- **Account Linking Query**: O(1) lookup by email (indexed)

## Next Steps

1. **Apply Migrations**: Follow `SUPABASE_AUTH_MIGRATION_GUIDE.md`
2. **Configure OAuth**: Set up providers in Supabase Dashboard
3. **Update App**: Integrate URL callback handling
4. **Test**: Verify OAuth flows work end-to-end
5. **Replace**: Swap `AuthService` with `AuthServiceV2` in all views
6. **Deploy**: Test with real users, monitor for issues

## Support

If you encounter issues:
1. Check Supabase logs: Dashboard → Logs → Auth
2. Check Xcode console for detailed error messages
3. Verify OAuth redirect URLs match in all places
4. Test with Supabase CLI local instance first

## Future Enhancements

- [ ] Add Google Sign In support
- [ ] Implement social login UI with provider selection
- [ ] Add account settings to manage connected providers
- [ ] Implement email/password as fallback auth
- [ ] Add MFA support via Supabase Auth
