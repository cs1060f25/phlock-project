# 🎵 musiclinkr Mobile

Convert music links between multiple streaming platforms on your iOS device.

## 🚀 Features

- **Multi-platform conversion** between 7 major music services:
  - Spotify ↔ Apple Music
  - YouTube ↔ YouTube Music
  - Amazon Music, Tidal, SoundCloud
- **Native iOS app** built with React Native + Expo
- **Clean, intuitive interface** optimized for mobile
- **Copy and share** converted links
- **Open links directly** in music apps
- **Bidirectional conversion** with arrow toggle

## 🛠️ Tech Stack

- **Framework:** React Native + Expo
- **Language:** JavaScript (ES6+)
- **APIs:** Spotify, Apple Music, YouTube, SoundCloud, SongLink
- **Platform:** iOS (with Android support ready)

## 📋 Setup

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed setup instructions.

### Quick Start

1. **Install Dependencies**
```bash
npm install
```

2. **Configure API Keys**
```bash
cp .env.example services/config.js
# Edit services/config.js with your API keys
```

3. **Run on iOS**
```bash
npm start
# Press 'i' to open in iOS Simulator
```

## 🔑 API Keys Setup

### Spotify Web API
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Get your **Client ID** and **Client Secret**
4. Add to environment variables:
   ```
   SPOTIFY_CLIENT_ID=your_client_id
   SPOTIFY_CLIENT_SECRET=your_client_secret
   ```

### Apple Music API
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Create a MusicKit identifier
3. Get your **Team ID**, **Key ID**, and generate a **Private Key**
4. Add to `services/config.js`

### YouTube Data API
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable YouTube Data API v3
3. Create an API key
4. Add to `services/config.js`

### SoundCloud API
1. Go to [SoundCloud Developers](https://developers.soundcloud.com/)
2. Register your app
3. Get Client ID and Client Secret
4. Add to `services/config.js`

**Note:** Amazon Music and Tidal use the SongLink API (no additional keys needed)

## 📦 Building for Production

### iOS App Store Build

```bash
# Install EAS CLI
npm install -g eas-cli

# Login to Expo
eas login

# Configure build
eas build:configure

# Build for iOS
eas build --platform ios --profile production

# Submit to App Store
eas submit --platform ios
```

## 📱 Usage

1. **Select platforms** by tapping the platform icons
2. **Toggle direction** using the arrow button
3. **Paste a music link** from any supported platform
4. **Tap the convert button** (flower icon)
5. **Copy or open** the converted link

### Supported URL formats:
- Spotify: `https://open.spotify.com/track/...`
- Apple Music: `https://music.apple.com/.../song/...`
- YouTube: `https://youtube.com/watch?v=...`
- YouTube Music: `https://music.youtube.com/watch?v=...`
- And more!

## 📁 Project Structure

```
musiclinkr mobile/
├── App.js                    # Main React Native component
├── services/                 # API services
│   ├── config.js            # API keys (gitignored)
│   ├── music-converter.js   # Main conversion logic
│   ├── spotify-api.js       # Spotify integration
│   ├── apple-music-api.js   # Apple Music integration
│   ├── youtube-api.js       # YouTube integration
│   ├── soundcloud-api.js    # SoundCloud integration
│   ├── songlink-api.js      # SongLink/Odesli API
│   └── tidal-api.js         # Tidal integration
├── app.json                 # Expo configuration
├── package.json             # Dependencies
└── babel.config.js          # Babel config
```

## 🎯 How It Works

1. **Platform Detection:** Automatically detects the source platform from the URL
2. **Track Extraction:** Extracts track information using platform-specific APIs
3. **Smart Matching:** Searches target platform and finds the best match based on:
   - Song title similarity
   - Artist name matching
   - Album information
   - Duration comparison
4. **Link Generation:** Creates the appropriate URL for the target platform

## ⚡ Performance

- Cached API tokens for faster conversions
- Smart similarity scoring (60%+ threshold)
- Fallback to SongLink API for difficult matches
- Handles multiple URL formats per platform

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- Built with [Expo](https://expo.dev/)
- Uses [SongLink API](https://odesli.co/) for certain conversions
- Platform icons from official brand guidelines
