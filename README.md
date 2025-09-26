# Phlock - Music Sharing Platform Prototype

## Overview
Phlock is a music-sharing platform prototype that sits on top of Spotify and Apple Music, designed to make sharing frictionless, recognize fan influence, and give artists new ways to activate and reward their communities. This prototype implements the complete user journey for both music fans and artists.

## Author Information
- **Name**: James Lee
- **GitHub Username**: woon-1
- **Deployed URL**: https://woon-1-hw3.vercel.app/
- **PRD URL**: https://docs.google.com/document/d/1eJh32rcI6-NksVm37WkApIthCmEnihBBJeEswglePJY/edit?usp=sharing

## Features Implemented

### Core User Journeys
- **Fan Journey**: Landing page → Fan home → Music discovery → Crate management → Sharing
- **Artist Journey**: Landing page → Artist home → Activity monitoring → Dashboard analytics → Fan engagement

### Key Functionality
- **Cross-platform Music Sharing**: Seamless sharing between Spotify and Apple Music users
- **The Crate**: Single collection where all successful recommendations live
- **Plug Score System**: Dynamic scoring for fan influence with leaderboards
- **Artist Dashboard**: Real-time analytics, top plugs, and sharing insights
- **Activity Feed**: Live feed of music sharing activities
- **Interactive Elements**: Like and comment functionality for artist engagement

### Technical Features
- **Mobile-first Design**: iPhone frame wrapper with responsive layout
- **Persistent Navigation**: Context-aware home button routing
- **Synthetic Data**: Realistic mock data for tracks, users, and activities
- **State Management**: React Context for global state
- **Modern UI**: Space Grotesk font, wavy dividers, and dark theme

## How to Run the Prototype

### Prerequisites
- Node.js (version 16 or higher)
- npm or yarn package manager

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/cs1060f25/woon-1-hw3.git
   cd woon-1-hw3
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start the development server**
   ```bash
   npm run dev
   ```

4. **Open in browser**
   - Navigate to `http://localhost:5173`
   - The prototype will load with the landing page

### Alternative: Use Deployed Version
The prototype is already deployed and available at: https://woon-1-hw3.vercel.app/

## User Journey Demo

### For Fans
1. Click "For Fans →" on landing page
2. Explore the activity feed and artist leaderboards
3. Navigate to "My Crate" to see saved music
4. Use "Search" to discover new music
5. Home button returns to fan home

### For Artists
1. Click "For Artists →" on landing page
2. View "mgk activity" feed with like/comment interactions
3. Access "mgk Dashboard" for analytics and insights
4. Monitor top plugs and sharing patterns
5. Home button returns to artist home

## Technical Stack
- **Frontend**: React 18 with TypeScript
- **Build Tool**: Vite
- **Routing**: React Router DOM
- **Styling**: Inline styles with CSS custom properties
- **Deployment**: Vercel
- **State Management**: React Context API

## Project Structure
```
src/
├── components/
│   └── WaveDivider.tsx    # Reusable wavy divider component
├── pages.tsx              # All page components and routing
├── store.tsx              # Global state management
├── data.ts                # Mock data and types
├── main.tsx               # App entry point and routing setup
└── index.css              # Global styles and phone frame
```

## Key Components
- **Landing**: Entry point with fan/artist selection
- **HomeMenuFan**: Fan home with activity feed and leaderboards
- **HomeMenuArtist**: Artist home with activity monitoring and dashboard
- **Crate**: Music collection with inbox and saved tracks
- **Search**: Music discovery interface
- **Leaderboard**: Artist-specific fan rankings
- **ArtistDashboard**: Analytics and insights for artists

## Mock Data
The prototype uses synthetic data including:
- 25+ tracks from artists like mgk, Dijon, Jai Paul, Daniel Caesar, Frank Ocean
- User profiles with Instagram-style usernames
- Activity feed with realistic timestamps
- Leaderboard data with diverse rankings
- Sharing insights and analytics

## Deployment
The prototype is automatically deployed to Vercel on every push to the main branch. The deployment URL is: https://woon-1-hw3.vercel.app/

## Browser Compatibility
- Chrome (recommended)
- Firefox
- Safari
- Edge

## Notes
- This is a prototype for demonstration purposes
- All data is synthetic and resets on page refresh
- The app is optimized for mobile viewing but works on desktop
- Navigation state is preserved using localStorage