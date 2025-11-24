# TestFlight Quick Start Checklist

## ✅ Completed
- [x] Privacy manifest created
- [x] iOS 16.0 compatibility ensured
- [x] Privacy policy template ready
- [x] Build verified successful
- [x] Version display added to app
- [x] Changes committed and pushed to git

## 🚀 Next Steps (In Order)

### 1. Host Privacy Policy (~10 minutes)
```bash
# Option A: GitHub Pages (Recommended)
1. Create new repo: github.com/[username]/phlock-privacy
2. Upload PRIVACY_POLICY.md
3. Enable Pages in settings
4. URL: https://[username].github.io/phlock-privacy

# Option B: Quick hosting services
- Vercel.com (drag and drop)
- Netlify.com (drag and drop)
- Pages.cloudflare.com
```

**Update before hosting:**
- Replace `support@phlock.app` with your email
- Replace `privacy@phlock.app` with your email
- Add your support URL

### 2. Create App in App Store Connect (~5 minutes)
1. Go to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Fill in:
   - Name: **Phlock**
   - Platform: **iOS**
   - Bundle ID: **com.phlock.phlock**
   - SKU: **phlock-001** (or any unique ID)
   - User Access: **Full Access**
4. Click "Create"

### 3. Add Privacy Policy URL (~1 minute)
1. In App Store Connect → Phlock → App Information
2. Privacy Policy URL: **[Paste your hosted URL from Step 1]**
3. Click "Save"

### 4. Take Screenshots (~15 minutes)
Run on iPhone 15 Pro Max simulator:
```bash
# Open in Xcode
cd apps/ios/phlock
open phlock.xcodeproj

# Run on iPhone 15 Pro Max simulator
# Navigate to these screens and press Cmd+S:
```

Capture these views:
1. **Welcome/Login** - Show platform selection
2. **Feed** - Friend activity with shares
3. **Discover** - Music search interface
4. **Inbox** - Received songs
5. **Profile** - User profile with Today's Pick

### 5. Archive and Upload (~20 minutes)

In Xcode:
```
1. Select device: "Any iOS Device (arm64)" (top toolbar)
2. Product → Clean Build Folder (Cmd+Shift+K)
3. Product → Archive (wait 2-5 min)
4. Organizer opens → "Distribute App"
5. Select "App Store Connect"
6. Select "Upload"
7. Keep defaults → Next → Upload
```

Wait for email: "Your app is ready for testing"

### 6. Configure TestFlight (~10 minutes)
1. App Store Connect → Phlock → TestFlight
2. Wait for build to process (5-15 min)
3. Click build → Export Compliance:
   - Uses encryption? **Yes**
   - Qualifies for exemption? **Yes**
   - Uses HTTPS only? **Yes**
4. Click "Start Internal Testing"

### 7. Add Test Information
Fill in:

**What to Test:**
```
- Sign in with Spotify or Apple Music
- Search for music in Discover
- Send songs to friends
- View friend activity in Feed
- Daily song picks

Known Issues:
- Some tracks lack preview URLs
```

**Beta App Description:**
```
Phlock lets you share music across Spotify and Apple Music.
Early beta - your feedback is invaluable!
```

**Feedback Email:** [Your email]
**Privacy Policy URL:** [Same URL from Step 3]

### 8. Invite Testers

**Internal Testing (No review needed):**
1. TestFlight → Internal Group
2. Click "+" to add testers
3. Add by email (must be App Store Connect users)
4. They get instant access

**External Testing (Requires review):**
1. TestFlight → Create External Group
2. Add testers by email (anyone)
3. Submit for Review
4. Wait 1-3 business days
5. Testers get email once approved

### 9. Send to Testers
Share this message:

```
Hey! I'm inviting you to test Phlock - my new music sharing app.

Setup:
1. Install TestFlight from App Store
2. Open this invitation on your iPhone
3. Tap "Install"

You'll need Spotify or Apple Music to use it.

Let me know what you think!
```

---

## 📊 Time Estimates

| Step | Time | Can Skip? |
|------|------|-----------|
| 1. Host privacy policy | 10 min | ❌ Required |
| 2. Create app | 5 min | ❌ Required |
| 3. Add privacy URL | 1 min | ❌ Required |
| 4. Take screenshots | 15 min | ✅ Can do later |
| 5. Archive & upload | 20 min | ❌ Required |
| 6. Configure TestFlight | 10 min | ❌ Required |
| 7. Add test info | 5 min | ✅ Recommended |
| 8. Invite testers | 5 min | ❌ Required |
| 9. Send instructions | 2 min | ✅ Recommended |

**Total minimum time:** ~50 minutes
**Total recommended time:** ~75 minutes

---

## 🆘 Quick Troubleshooting

**Build fails?**
→ Check Signing & Capabilities → Select your team

**Can't upload to App Store Connect?**
→ Verify you selected "Any iOS Device (arm64)", not simulator

**Privacy policy URL rejected?**
→ Ensure URL is publicly accessible (not localhost)

**Build stuck "Processing"?**
→ Wait up to 30 minutes, check your email

**Testers can't install?**
→ Verify their email matches their Apple ID

---

## 📚 Full Guides

Detailed instructions in these files:
- **[TESTFLIGHT_DEPLOYMENT_GUIDE.md](TESTFLIGHT_DEPLOYMENT_GUIDE.md)** - Complete walkthrough
- **[TESTFLIGHT_CHANGES_SUMMARY.md](TESTFLIGHT_CHANGES_SUMMARY.md)** - What changed
- **[PRIVACY_POLICY.md](PRIVACY_POLICY.md)** - Template to host

---

## ✨ You're Ready!

Everything is prepared. Just follow the 9 steps above and you'll have testers within a few hours.

**First time?** Budget ~2 hours for the full process.
**Done it before?** Should take ~1 hour.

Good luck! 🚀
