# Search Spotify Artist Edge Function

This Supabase Edge Function searches for a Spotify artist by name and returns their Spotify ID. It keeps the Spotify client secret secure on the server side.

## Setup

1. Set the following secrets in your Supabase project:

```bash
supabase secrets set SPOTIFY_CLIENT_ID=your_spotify_client_id
supabase secrets set SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
```

2. Deploy the function:

```bash
supabase functions deploy search-spotify-artist
```

## Usage

### Request

```json
POST https://your-project.supabase.co/functions/v1/search-spotify-artist
{
  "artistName": "Taylor Swift"
}
```

### Response

Success:
```json
{
  "spotifyId": "06HL4z0CvFAxyc27GXpf02",
  "artistName": "Taylor Swift"
}
```

Not found:
```json
{
  "spotifyId": null
}
```

Error:
```json
{
  "error": "Error message"
}
```

## Environment Variables

- `SPOTIFY_CLIENT_ID` - Your Spotify application client ID
- `SPOTIFY_CLIENT_SECRET` - Your Spotify application client secret

Get these from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
