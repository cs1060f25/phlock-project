// Amazon Music API Service
class AmazonMusicAPI {
    constructor() {
        this.clientId = process.env.AMAZON_MUSIC_CLIENT_ID;
        this.clientSecret = process.env.AMAZON_MUSIC_CLIENT_SECRET;
        this.baseUrl = 'https://api.music.amazon.dev';
        this.accessToken = null;
        this.tokenExpiry = null;
    }

    // Get OAuth 2.0 access token
    async getAccessToken() {
        // Check if we have a valid token
        if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
            return this.accessToken;
        }

        try {
            const response = await fetch('https://api.amazon.com/auth/o2/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: new URLSearchParams({
                    'grant_type': 'client_credentials',
                    'client_id': this.clientId,
                    'client_secret': this.clientSecret
                }).toString()
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('Amazon auth response:', errorText);
                throw new Error(`Failed to get Amazon Music token: ${response.status} ${errorText}`);
            }

            const data = await response.json();
            this.accessToken = data.access_token;
            this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // Refresh 1 min early

            return this.accessToken;

        } catch (error) {
            console.error('Amazon Music authentication error:', error);
            throw error;
        }
    }

    // Extract track or album ID from Amazon Music URL
    static extractTrackId(url) {
        try {
            // Amazon Music URLs: https://music.amazon.com/albums/B0XXXXXX?trackAsin=B0YYYYYY
            // or: https://music.amazon.com/tracks/B0YYYYYY
            const urlObj = new URL(url);
            
            // Track from query parameter
            const trackAsin = urlObj.searchParams.get('trackAsin');
            if (trackAsin) return trackAsin;
            
            // Track from path
            const pathMatch = urlObj.pathname.match(/\/tracks\/([A-Z0-9]+)/);
            if (pathMatch) return pathMatch[1];
            
            return null;
        } catch (error) {
            console.error('Error extracting Amazon Music track ID:', error);
            return null;
        }
    }

    // Generate Amazon Music URL
    static generateUrl(trackId) {
        return `https://music.amazon.com/tracks/${trackId}`;
    }

    // Search for tracks
    async searchTracks(query, limit = 20) {
        try {
            const token = await this.getAccessToken();
            
            const params = new URLSearchParams({
                query: query,
                limit: limit,
                type: 'track'
            });

            const response = await fetch(`${this.baseUrl}/v1/search?${params}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'x-api-key': this.clientId
                }
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.message || 'Amazon Music API request failed');
            }

            const data = await response.json();
            return data.tracks?.items || [];

        } catch (error) {
            console.error('Amazon Music search error:', error);
            throw error;
        }
    }

    // Get track by ID
    async getTrack(trackId) {
        try {
            const token = await this.getAccessToken();

            const response = await fetch(`${this.baseUrl}/v1/tracks/${trackId}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'x-api-key': this.clientId
                }
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.message || 'Track not found');
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('Amazon Music get track error:', error);
            throw error;
        }
    }
}

export default AmazonMusicAPI;

