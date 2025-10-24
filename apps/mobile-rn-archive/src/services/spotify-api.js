// Spotify Web API Service
class SpotifyAPI {
    constructor() {
        this.baseURL = 'https://api.spotify.com/v1';
        this.clientId = process.env.SPOTIFY_CLIENT_ID;
        this.clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
        this.accessToken = null;
        this.tokenExpiry = null;
    }

    async getAccessToken() {
        // Check if we have a valid token
        if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
            return this.accessToken;
        }

        // Get new token using client credentials flow
        try {
            const response = await fetch('https://accounts.spotify.com/api/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Authorization': `Basic ${btoa(`${this.clientId}:${this.clientSecret}`)}`
                },
                body: 'grant_type=client_credentials'
            });

            if (!response.ok) {
                throw new Error(`Spotify auth failed: ${response.status}`);
            }

            const data = await response.json();
            this.accessToken = data.access_token;
            this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // 1 minute buffer

            return this.accessToken;
        } catch (error) {
            console.error('Spotify authentication error:', error);
            throw new Error('Failed to authenticate with Spotify');
        }
    }

    async getTrack(trackId) {
        try {
            const token = await this.getAccessToken();
            const response = await fetch(`${this.baseURL}/tracks/${trackId}`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (!response.ok) {
                throw new Error(`Spotify API error: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('Error fetching Spotify track:', error);
            throw error;
        }
    }

    async searchTracks(query, limit = 10) {
        try {
            const token = await this.getAccessToken();
            const response = await fetch(`${this.baseURL}/search?q=${encodeURIComponent(query)}&type=track&limit=${limit}`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (!response.ok) {
                throw new Error(`Spotify search error: ${response.status}`);
            }

            const data = await response.json();
            return data.tracks.items;
        } catch (error) {
            console.error('Error searching Spotify:', error);
            throw error;
        }
    }

    // Extract track ID from Spotify URL
    static extractTrackId(url) {
        try {
            const match = url.match(/\/track\/([a-zA-Z0-9]+)/);
            return match ? match[1] : null;
        } catch (error) {
            return null;
        }
    }

    // Generate Spotify URL from track ID
    static generateUrl(trackId) {
        return `https://open.spotify.com/track/${trackId}`;
    }
}

export default SpotifyAPI;
