# Prototype 4: Full-Stack Dashboard

## Design Approach
Enterprise-grade Spotify-inspired dashboard with user authentication, server-side API, and persistent database storage. 

## Tech Stack
- **Frontend**: Next.js (React) with Pages Router
- **Backend**: Next.js API Routes
- **Database**: JSON file storage (would be Vercel Postgres in production)
- **Styling**: Inline CSS with Spotify-inspired dark theme
- **Authentication**: Simple username-based (would be OAuth in production)

## Key Features
- User login system (username-based)
- Server-side API endpoints for CRUD operations
- Persistent storage across sessions and users
- Multi-user support (each user has their own crate)
- Shareable URLs (each user has a unique collection)
- Professional Spotify-inspired UI
- Statistics dashboard
- Responsive layout with sidebar navigation

## Architecture

### Client-Server Separation
- **Frontend** (`/pages/index.js`): React component making API calls
- **Backend** (`/pages/api/tracks.js`): RESTful API handling business logic
- **Database** (`data.json`): Persistent storage (simulating Postgres)

### API Endpoints

**GET /api/tracks?user={username}**
- Fetch all tracks for a specific user

**POST /api/tracks**
```json
{
  "user": "username",
  "platform": "Spotify",
  "url": "https://..."
}
```
- Add a new track to user's crate

**DELETE /api/tracks**
```json
{
  "user": "username",
  "id": 1234567890
}
```
- Remove a track from user's crate

## Design Decisions

### Why This is the Most Complete Approach

1. **Scalability**:
   - Multi-user support
   - Server-side logic can be extended
   - Database can be swapped for Postgres/MongoDB

2. **Security**:
   - Server-side validation
   - No direct client access to data
   - Can add authentication middleware

3. **Persistence**:
   - Data survives browser clears
   - Accessible from any device
   - Multi-user isolation

4. **Professional UI**:
   - Spotify-inspired design language
   - User login/logout flow
   - Sidebar navigation
   - Statistics dashboard

5. **Production-Ready**:
   - RESTful API design
   - Error handling
   - Deployment configuration
   - Easy to migrate to real database

## Production Enhancements

In a real production environment, this would include:
- Vercel Postgres instead of JSON file
- NextAuth.js for OAuth (Google, Spotify, etc.)
- Server-side rendering for SEO
- Rate limiting and security headers
- User profiles and avatars
- Music metadata fetching (using Spotify API)
- Album artwork display
- Playlist organization
- Social features (sharing, following)

## To Run Locally
```bash
npm install
npm run dev
```

## To Deploy to Vercel
```bash
vercel --prod
```

Note: For Vercel deployment, you'd want to migrate from JSON file storage to Vercel Postgres:
1. Create a Postgres database in Vercel dashboard
2. Install `@vercel/postgres`
3. Replace file I/O with SQL queries
