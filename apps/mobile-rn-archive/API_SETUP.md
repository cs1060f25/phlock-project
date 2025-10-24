# 🔑 API Setup Guide

## Required Environment Variables

Add these to your Vercel project settings:

### Spotify Web API
```
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
```

### Apple Music API
```
APPLE_MUSIC_TEAM_ID=your_apple_team_id
APPLE_MUSIC_KEY_ID=your_apple_key_id
APPLE_MUSIC_PRIVATE_KEY=your_apple_private_key
```

### YouTube Data API v3
```
YOUTUBE_API_KEY=your_youtube_api_key
```

## How to Get API Keys

### 1. Spotify Web API

1. **Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)**
2. **Create a new app:**
   - Click "Create App"
   - App name: "Music Link Converter"
   - App description: "Convert music links between platforms"
   - Website: Your domain
   - Redirect URI: `http://localhost:3000/callback` (for testing)
3. **Get credentials:**
   - Copy **Client ID**
   - Copy **Client Secret**
4. **Add to Vercel:**
   - Go to Vercel Dashboard → Your Project → Settings → Environment Variables
   - Add `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`

### 2. Apple Music API

1. **Join Apple Developer Program** (if not already)
   - Go to [Apple Developer Portal](https://developer.apple.com/programs/)
   - Sign up ($99/year)

2. **Create MusicKit Identifier:**
   - Go to [Apple Developer Portal](https://developer.apple.com/account/)
   - Certificates, Identifiers & Profiles → Identifiers
   - Click "+" → MusicKit
   - Description: "Music Link Converter"
   - Identifier: `com.yourcompany.musiclinkconverter`
   - Register

3. **Create Private Key:**
   - Certificates, Identifiers & Profiles → Keys
   - Click "+" → Create new key
   - Name: "Music Link Converter Key"
   - Enable "MusicKit" capability
   - Register → Download `.p8` file
   - **Save the Key ID** (you'll need it)

4. **Get Team ID:**
   - In Apple Developer Portal, look at the top right
   - Copy your **Team ID** (10-character string)

5. **Add to Vercel:**
   - Add `APPLE_MUSIC_TEAM_ID` (your Team ID)
   - Add `APPLE_MUSIC_KEY_ID` (from step 3)
   - Add `APPLE_MUSIC_PRIVATE_KEY` (contents of the .p8 file)

### 3. YouTube Data API v3

1. **Go to [Google Cloud Console](https://console.cloud.google.com/)**
2. **Create a new project** (if you haven't already)
3. **Enable YouTube Data API v3:**
   - Go to APIs & Services → Library
   - Search for "YouTube Data API v3"
   - Click "Enable"
4. **Create API Key:**
   - Go to APIs & Services → Credentials
   - Click "Create Credentials" → "API Key"
   - Copy the API key
5. **Restrict the key (recommended):**
   - Click on the key to edit
   - Under "API restrictions", select "Restrict key"
   - Select only "YouTube Data API v3"
   - Save
6. **Add to Vercel:**
   - Add `YOUTUBE_API_KEY` with your API key

## Testing Your Setup

Once you've added all environment variables:

1. **Redeploy your Vercel project**
2. **Test with real URLs:**
   - Spotify: `https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh`
   - Apple Music: `https://music.apple.com/us/album/anti-hero/1646849437?i=1646849440`

## Troubleshooting

### Common Issues:

1. **"Failed to authenticate with Spotify"**
   - Check Client ID and Secret are correct
   - Ensure app is created in Spotify Dashboard

2. **"Failed to generate Apple Music token"**
   - Check Team ID, Key ID, and Private Key
   - Ensure MusicKit capability is enabled
   - Verify .p8 file contents are correct

3. **"No matching track found"**
   - This is normal - not all songs exist on both platforms
   - Try with more popular songs first

### Rate Limits:
- **Spotify:** 10,000 requests per hour
- **Apple Music:** 20,000 requests per hour

## Next Steps

After setup:
1. Test with various songs
2. Monitor conversion accuracy
3. Add caching for better performance
4. Consider adding more platforms (YouTube Music, etc.)
