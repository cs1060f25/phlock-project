// Tidal API Service
class TidalAPI {
    constructor() {
        this.clientId = process.env.TIDAL_CLIENT_ID;
        this.clientSecret = process.env.TIDAL_CLIENT_SECRET;
        this.baseUrl = 'https://openapi.tidal.com/v2';
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
            console.log('Getting Tidal token...');
            console.log('Client ID exists:', !!this.clientId);
            console.log('Client Secret exists:', !!this.clientSecret);
            
            const credentials = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
            
            const response = await fetch('https://auth.tidal.com/v1/oauth2/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Authorization': `Basic ${credentials}`
                },
                body: new URLSearchParams({
                    'grant_type': 'client_credentials'
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('Tidal auth failed:', response.status, response.statusText);
                console.error('Tidal auth response:', errorText);
                throw new Error(`Failed to get Tidal token: ${response.status}`);
            }

            const data = await response.json();
            console.log('Tidal token obtained successfully');
            this.accessToken = data.access_token;
            this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // Refresh 1 min early

            return this.accessToken;

        } catch (error) {
            console.error('Tidal authentication error:', error);
            throw error;
        }
    }

    // Extract track ID from Tidal URL
    static extractTrackId(url) {
        try {
            // Tidal URLs: https://tidal.com/browse/track/123456789
            // or: https://listen.tidal.com/track/123456789
            const urlObj = new URL(url);
            const pathMatch = urlObj.pathname.match(/\/track\/(\d+)/);
            if (pathMatch) return pathMatch[1];
            
            return null;
        } catch (error) {
            console.error('Error extracting Tidal track ID:', error);
            return null;
        }
    }

    // Generate Tidal URL
    static generateUrl(trackId) {
        return `https://tidal.com/browse/track/${trackId}`;
    }

    // Search for tracks
    async searchTracks(query, limit = 20) {
        try {
            const token = await this.getAccessToken();
            
            // Try v2 search endpoint first
            const params = new URLSearchParams({
                query: query,
                limit: limit,
                countryCode: 'US',
                type: 'TRACKS'
            });

            const searchUrl = `${this.baseUrl}/searchresults/${encodeURIComponent(query)}?countryCode=US&limit=${limit}&offset=0&types=TRACKS`;
            console.log('Trying Tidal search URL:', searchUrl);

            const response = await fetch(searchUrl, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'accept': 'application/vnd.tidal.v1+json',
                    'Content-Type': 'application/vnd.tidal.v1+json'
                }
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('Tidal search response:', response.status, errorText);
                throw new Error(`Tidal search failed: ${response.status}`);
            }

            const data = await response.json();
            console.log('Tidal search data structure:', JSON.stringify(data).substring(0, 500));
            return data.tracks?.items || data.items || [];

        } catch (error) {
            console.error('Tidal search error:', error);
            throw error;
        }
    }

    // Get track by ID
    async getTrack(trackId) {
        try {
            const token = await this.getAccessToken();

            const params = new URLSearchParams({
                countryCode: 'US'
            });

            const response = await fetch(`${this.baseUrl}/tracks/${trackId}?${params}`, {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'accept': 'application/vnd.tidal.v1+json',
                    'Content-Type': 'application/vnd.tidal.v1+json'
                }
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('Tidal v2 get track response:', response.status, errorText);
                throw new Error(`Track not found: ${response.status}`);
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('Tidal get track error:', error);
            throw error;
        }
    }
}

export default TidalAPI;

