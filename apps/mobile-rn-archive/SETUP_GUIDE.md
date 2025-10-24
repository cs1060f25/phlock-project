# Setup Guide for musiclinkr Mobile

## Quick Start

### 1. Install Dependencies

```bash
cd "musiclinkr mobile"
npm install
```

### 2. Configure API Keys

The app requires API keys from various music services. Create your `services/config.js` file:

```bash
cp .env.example services/config.js
```

Then edit `services/config.js` and replace the placeholder values with your actual API keys.

### 3. Getting API Keys

#### Spotify API
1. Go to https://developer.spotify.com/dashboard
2. Create a new app
3. Copy your Client ID and Client Secret
4. Add them to `services/config.js`

#### Apple Music API
1. Join the Apple Developer Program
2. Go to https://developer.apple.com/account
3. Create a MusicKit identifier
4. Generate a private key
5. Add Team ID, Key ID, and Private Key to `services/config.js`

#### YouTube Data API
1. Go to https://console.cloud.google.com/
2. Create a new project
3. Enable YouTube Data API v3
4. Create credentials (API Key)
5. Add the API key to `services/config.js`

#### SoundCloud API
1. Go to https://developers.soundcloud.com/
2. Register your app
3. Get your Client ID and Client Secret
4. Add them to `services/config.js`

**Note:** Tidal and Amazon Music conversions use the SongLink API, which doesn't require additional keys.

### 4. Run the App

Start the development server:

```bash
npm start
```

Then press `i` to open in iOS Simulator.

## Troubleshooting

### "Failed to authenticate with [Service]"
- Make sure your API keys are correctly configured in `services/config.js`
- Check that the keys haven't expired
- Verify your API quotas haven't been exceeded

### App won't start
- Run `npm install` again
- Clear Expo cache: `expo start -c`
- Make sure you have the latest version of Expo CLI

### Can't open links in apps
- On iOS, make sure the URL schemes are properly configured in `app.json`
- Some music apps may not support deep linking

## Development Tips

- Use `expo start --ios` to directly open in iOS simulator
- Use `expo start --clear` to clear the cache if you have issues
- Check the Expo DevTools in your browser for logs and debugging

## Production Build

To create a production build:

```bash
# Install EAS CLI
npm install -g eas-cli

# Login to Expo
eas login

# Configure EAS
eas build:configure

# Build for iOS
eas build --platform ios --profile production
```
