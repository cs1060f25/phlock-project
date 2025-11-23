# TestFlight Deployment Guide for Phlock

This guide will walk you through the complete process of deploying Phlock to TestFlight for beta testing.

## ✅ Prerequisites Completed

The following items have been prepared for you:

- [x] Privacy manifest file ([PrivacyInfo.xcprivacy](apps/ios/phlock/phlock/PrivacyInfo.xcprivacy))
- [x] Deployment target lowered to iOS 16.0 (from 26.0)
- [x] Privacy policy template ([PRIVACY_POLICY.md](PRIVACY_POLICY.md))
- [x] Version display in Profile settings
- [x] Build successfully compiles

## 📋 Before You Start

### Required Accounts
1. **Apple Developer Account** (Individual or Organization)
   - URL: https://developer.apple.com
   - Cost: $99/year
   - Needed for: TestFlight and App Store distribution

2. **App Store Connect Access**
   - URL: https://appstoreconnect.apple.com
   - Your Apple Developer account must have "Admin" or "App Manager" role

### Required Tools
- Xcode 15+ (you have this)
- macOS device (you have this)
- Physical iOS device for testing (recommended)

---

## 📱 Step 1: Host Your Privacy Policy

Apple requires a publicly accessible privacy policy URL before you can submit to TestFlight.

### Option A: GitHub Pages (Free, Recommended)

1. Create a new repository called `phlock-privacy` on GitHub
2. Convert [PRIVACY_POLICY.md](PRIVACY_POLICY.md) to HTML or use GitHub's automatic rendering
3. Enable GitHub Pages in repository settings
4. Your privacy policy URL will be: `https://[your-username].github.io/phlock-privacy`

### Option B: Simple Static Hosting

Use any of these free services:
- **Vercel** (vercel.com)
- **Netlify** (netlify.com)
- **Cloudflare Pages** (pages.cloudflare.com)

### Update the Privacy Policy Template

Before hosting, update `PRIVACY_POLICY.md` with:
- Replace `support@phlock.app` with your actual support email
- Replace `privacy@phlock.app` with your privacy contact email
- Add your actual support website URL
- Review with legal counsel (recommended but optional for beta)

---

## 🍎 Step 2: Configure App Store Connect

### 2.1 Create Your App

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps"
3. Click the "+" button and select "New App"

### 2.2 Fill in App Information

**Platforms:** iOS

**Name:** Phlock

**Primary Language:** English (U.S.)

**Bundle ID:** Select `com.phlock.phlock` (should already exist from your Xcode project)

**SKU:** Enter a unique identifier (e.g., `phlock-001`)
   - This is internal only, users won't see it
   - Can be anything unique, like your bundle ID

**User Access:** Full Access

Click "Create"

### 2.3 Complete App Information

Navigate to the "App Information" section and fill in:

**Privacy Policy URL:** [Your hosted privacy policy URL from Step 1]

**Category:**
- Primary: Music
- Secondary: Social Networking (optional)

**Content Rights:**
- Check "No, it does not contain, show, or access third-party content"
- (You're using Spotify/Apple Music data with user permission)

**Age Rating:** Complete the questionnaire
- Suggested answers for Phlock:
  - No for all violence/sexual content
  - No for gambling
  - Unrestricted Web Access: Yes (for music previews)
  - Result should be: 4+

---

## 🖼️ Step 3: Prepare App Store Assets

### 3.1 Screenshots (Required)

You need screenshots for iPhone. Take screenshots showing:

1. **Feed View** - Show friend activity
2. **Discover** - Music search interface
3. **Inbox** - Received shares
4. **Profile** - User profile with stats
5. **Share Flow** - Sending a song to friends

**Required Sizes:**
- iPhone 6.7" Display (iPhone 15 Pro Max): 1290 x 2796 pixels
- iPhone 6.5" Display (iPhone 11 Pro Max): 1242 x 2688 pixels

**How to Capture:**
1. Run app on simulator: iPhone 15 Pro Max
2. Navigate to each view
3. Use Cmd+S to save screenshots
4. Screenshots saved to Desktop

**Tip:** You can use the same screenshots for multiple device sizes - App Store Connect will scale them.

### 3.2 App Preview Video (Optional, but Recommended)

15-30 second video showing core features:
- Login with Spotify/Apple Music
- Discover and share a song
- View friend activity in feed

Use QuickTime Screen Recording on simulator.

---

## 🔧 Step 4: Configure Xcode Project

### 4.1 Verify Bundle Identifier

1. Open `apps/ios/phlock/phlock.xcodeproj` in Xcode
2. Select the "phlock" target
3. Go to "Signing & Capabilities"
4. **Bundle Identifier:** Verify it shows `com.phlock.phlock`
5. **Team:** Select your Apple Developer team
6. **Signing Certificate:** Should auto-select "Apple Development" or "Apple Distribution"

### 4.2 Enable Automatic Signing

1. In "Signing & Capabilities" tab
2. Check "Automatically manage signing"
3. Select your development team
4. Xcode will automatically create/download necessary certificates and provisioning profiles

### 4.3 Verify Capabilities

Your app should have these capabilities enabled:
- [x] Sign in with Apple
- [x] MusicKit (if using Apple Music)

These are already configured in your [phlock.entitlements](apps/ios/phlock/phlock/phlock.entitlements) file.

---

## 📦 Step 5: Archive and Upload

### 5.1 Select Build Destination

1. In Xcode, at the top near the Run button
2. Click the device/simulator selector
3. Select **"Any iOS Device (arm64)"**
4. Do NOT select a simulator - archives can only be created for real devices

### 5.2 Clean Build

1. In Xcode menu: **Product → Clean Build Folder** (or Cmd+Shift+K)
2. Wait for clean to complete

### 5.3 Create Archive

1. In Xcode menu: **Product → Archive**
2. Wait for archive to complete (2-5 minutes)
3. Xcode Organizer window will open automatically

If archive fails:
- Check Build Settings → Code Signing Identity is set
- Verify your Apple Developer account is active
- Check Console logs for specific errors

### 5.4 Upload to App Store Connect

1. In the Organizer window, select your latest archive
2. Click **"Distribute App"**
3. Select **"App Store Connect"**
4. Click **"Next"**
5. Select **"Upload"** (not "Export")
6. Click **"Next"**
7. Leave all defaults:
   - App Store Connect distribution options
   - Automatically manage signing ✓
   - Upload symbols ✓ (for crash reports)
8. Click **"Next"**
9. Review the app information
10. Click **"Upload"**

Upload takes 2-10 minutes depending on your internet speed.

You'll see: "Upload Successful! Your app will appear in App Store Connect shortly."

---

## 🧪 Step 6: Configure TestFlight

### 6.1 Wait for Processing

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to "My Apps" → "Phlock"
3. Click "TestFlight" tab
4. Your build will show as "Processing" - this takes 5-15 minutes
5. You'll receive an email when processing completes

### 6.2 Add Export Compliance

Once processing is complete:

1. Click on your build number (e.g., "1.0 (1)")
2. In the "Export Compliance Information" section:
   - **Does your app use encryption?** → Yes
   - **Does your app qualify for exemption?** → Yes
   - **Why?** → Select "App uses HTTPS only"
   - This applies to most apps that only use HTTPS for API calls
3. Click "Start Internal Testing"

### 6.3 Add Test Information

Fill in the Test Details:

**What to Test:**
```
Phlock is a social music discovery app. Focus on:

- Signing in with Spotify or Apple Music
- Searching for music in Discover tab
- Sending songs to friends
- Viewing received songs in Inbox
- Checking friend activity in Feed
- Daily playlist feature (Today's Pick)

Known Limitations:
- Some tracks may not have 30-second preview URLs
- Apple Music search is limited compared to Spotify
```

**Beta App Description:**
```
Phlock lets you share music with friends across Spotify and Apple Music.
Discover what your friends are listening to, share your favorite tracks,
and keep a streak alive with daily song picks.

This is an early beta - your feedback is invaluable!
```

**Feedback Email:** [Your email for tester feedback]

**Marketing URL:** (Optional - can leave blank)

**Privacy Policy URL:** [Your privacy policy URL from Step 1]

**Sign-In Information:** (If testers need accounts)
```
Testers need their own Spotify or Apple Music account.
No special test accounts required.
```

---

## 👥 Step 7: Add Testers

### Internal Testing (Up to 100 testers, no review required)

1. Go to TestFlight tab → Internal Group
2. Click "App Store Connect Users" group (or create a new group)
3. Click the "+" next to Testers
4. Add testers by email:
   - They must be added as users in App Store Connect first
   - Go to "Users and Access" to add them
   - Role can be "Customer Support" (limited access) or higher
5. Testers receive an email invitation immediately
6. They install TestFlight app from App Store
7. Open the invitation link to install Phlock

### External Testing (Unlimited testers, requires Apple review)

1. Go to TestFlight tab → External Testing
2. Click "+" to create a new group (e.g., "Beta Testers")
3. Add build to the group
4. Add testers by email (they don't need to be App Store Connect users)
5. Click "Submit for Review"
6. Fill in:
   - **What's new in this build:** Describe the features
   - **Contact information:** Your email
   - **App Reviewer Sign-in:** (if needed for testing)
7. Review typically takes 1-3 business days
8. Once approved, testers receive email invitations

---

## 🚀 Step 8: Distribute to Testers

### Send Invitations

Once your build is ready:

1. Testers receive an email: "You're invited to test Phlock"
2. Email contains a link to download TestFlight app
3. Testers open the link on their iOS device
4. TestFlight app opens automatically
5. Tap "Accept" then "Install"
6. Phlock appears on their home screen with an orange beta dot

### TestFlight Features

Testers can:
- Send feedback through TestFlight app
- View build information and what's new
- Automatically receive updates when you upload new builds
- See how many days until the build expires (90 days)

---

## 🔄 Step 9: Update Your Beta

When you want to release a new version:

### 9.1 Update Version/Build Number

In Xcode:
1. Select phlock target
2. Go to "General" tab
3. **Version:** Increment if adding features (1.0 → 1.1)
4. **Build:** Always increment (1 → 2, 2 → 3, etc.)
5. Must be higher than previous build sent to TestFlight

### 9.2 Add Release Notes

In your code or keep track separately:
```
Version 1.1 (Build 2) - November 24, 2025
- Fixed preview URL playback issues
- Improved friend search performance
- Added pull-to-refresh on Feed
- Bug fixes and improvements
```

### 9.3 Archive and Upload

1. Repeat Step 5 (Archive and Upload)
2. New build appears in App Store Connect
3. Wait for processing
4. Once processed, testers automatically get notified of update
5. They can choose to auto-update or manually update in TestFlight

---

## 📊 Step 10: Monitor TestFlight Analytics

### View Metrics

App Store Connect → Phlock → TestFlight tab:

**Metrics to Track:**
- Number of testers invited
- Number of testers who installed
- Number of active testers (last 30 days)
- Crash data (click "Crashes" in tab)
- Feedback submissions

### Crash Reports

1. Go to TestFlight → [Your Build] → Crashes
2. View crash logs with stack traces
3. Crashes are automatically symbolicated (readable)
4. Debug and fix before next build

### Collect Feedback

Testers can send feedback:
- In TestFlight app: Screenshot → Share Feedback
- Via email (if you provided feedback email)
- Through your own feedback mechanism in the app

---

## ⚠️ Troubleshooting

### "Invalid Bundle" Error
- **Cause:** Code signing issue or missing entitlements
- **Fix:** Check Signing & Capabilities in Xcode, ensure team is selected

### "Missing Privacy Policy URL"
- **Cause:** Privacy policy URL not added in App Store Connect
- **Fix:** Go to App Information and add privacy policy URL

### "Processing" Takes Too Long (>30 minutes)
- **Cause:** Apple server issues
- **Fix:** Wait a bit longer or contact Apple Support

### Build Doesn't Appear in TestFlight
- **Cause:** Export compliance not submitted
- **Fix:** Complete export compliance information

### Testers Can't Install
- **Cause:** Email doesn't match Apple ID, or iOS version too low
- **Fix:** Verify tester's email is their Apple ID email. Check iOS version >= 16.0

### "Could Not Find Member" When Adding Testers
- **Cause:** For internal testing, user must be added to App Store Connect first
- **Fix:** Go to "Users and Access" and add them as a user

---

## 📱 Recommended Testing Flow

### Before Sending to External Testers

1. **Internal Testing First** (1-2 weeks)
   - Invite your close friends/team (up to 100)
   - Get initial feedback and fix critical bugs
   - No Apple review needed, immediate access

2. **Fix Critical Issues**
   - Based on internal tester feedback
   - Upload new builds as needed
   - Iterate quickly

3. **External Testing** (wider audience)
   - Once app is relatively stable
   - Submit for review
   - Invite broader audience

### Tester Instructions to Share

Send this to your testers:

```
Thanks for beta testing Phlock!

Setup:
1. Install TestFlight app from App Store
2. Open invitation email on your iPhone
3. Tap "View in TestFlight"
4. Install Phlock

First Launch:
1. Sign in with Spotify or Apple Music
2. Grant permissions (contacts optional)
3. Set up your profile
4. Search for friends or use contact sync

What to Test:
- Discover: Search for songs/artists
- Share: Send songs to friends
- Inbox: View received songs
- Feed: See what friends are sharing
- Profile: Today's pick and stats

Send Feedback:
- In TestFlight: Take screenshot → Share Feedback
- Or email: [your-email]

Known Issues:
- Some tracks don't have previews
- Contact sync might miss some users

Thanks for helping make Phlock better!
```

---

## 🎉 Next Steps After TestFlight

Once you have:
- ✅ 10-50+ active beta testers
- ✅ Positive feedback
- ✅ Major bugs fixed
- ✅ Core features working well

You're ready for **App Store Review** and public launch!

That process involves:
1. App Store screenshots and description (build on TestFlight assets)
2. App Review submission (stricter than TestFlight)
3. Metadata and pricing
4. Release!

But for now, focus on getting quality feedback from TestFlight users.

---

## 📞 Support Resources

**Apple Documentation:**
- TestFlight Overview: https://developer.apple.com/testflight/
- App Store Connect Help: https://help.apple.com/app-store-connect/
- Distribution Guide: https://developer.apple.com/distribute/

**Common Issues:**
- Apple Developer Forums: https://developer.apple.com/forums/
- Stack Overflow Tag: `testflight`

**Phlock-Specific:**
- Your CLAUDE.md file for project context
- Build settings in Xcode project
- This guide!

---

## ✅ Pre-Flight Checklist

Before you start the actual deployment, make sure:

- [ ] Apple Developer account is active ($99/year paid)
- [ ] Privacy policy is hosted and accessible via URL
- [ ] App builds successfully in Xcode (verified ✓)
- [ ] You have at least 2-3 friends with Spotify/Apple Music to invite as initial testers
- [ ] You have a valid email for tester feedback
- [ ] You've tested the app on a real iOS device (not just simulator)
- [ ] All OAuth redirects work on physical device
- [ ] Database/Supabase connection works on physical device

---

**Good luck with your TestFlight launch! 🚀**

If you encounter any issues, refer to the Troubleshooting section or reach out to Apple Developer Support.

Remember: TestFlight is for testing, not perfection. Get it out to testers, gather feedback, and iterate!
