// SoundCloud API Service
class SoundCloudAPI {
    constructor() {
        this.clientId = process.env.SOUNDCLOUD_CLIENT_ID;
        this.clientSecret = process.env.SOUNDCLOUD_CLIENT_SECRET;
        this.baseUrl = 'https://api.soundcloud.com';
        this.accessToken = null;
        this.tokenExpiry = null;
    }

    // Get OAuth 2.0 access token using client credentials
    async getAccessToken() {
        // Check if we have a valid token
        if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry) {
            return this.accessToken;
        }

        try {
            console.log('Getting SoundCloud token...');
            console.log('Client ID exists:', !!this.clientId);
            console.log('Client Secret exists:', !!this.clientSecret);

            const response = await fetch('https://api.soundcloud.com/oauth2/token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: new URLSearchParams({
                    'grant_type': 'client_credentials',
                    'client_id': this.clientId,
                    'client_secret': this.clientSecret
                })
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('SoundCloud auth failed:', response.status, response.statusText);
                console.error('SoundCloud auth response:', errorText);
                throw new Error(`Failed to get SoundCloud token: ${response.status}`);
            }

            const data = await response.json();
            console.log('SoundCloud token obtained successfully');
            this.accessToken = data.access_token;
            this.tokenExpiry = Date.now() + (data.expires_in * 1000) - 60000; // Refresh 1 min early

            return this.accessToken;

        } catch (error) {
            console.error('SoundCloud authentication error:', error);
            throw error;
        }
    }

    // Extract track ID from SoundCloud URL
    static extractTrackId(url) {
        try {
            // SoundCloud URLs: https://soundcloud.com/artist/track-name
            // API resolve endpoint can convert URLs to IDs
            return url;
        } catch (error) {
            console.error('Error extracting SoundCloud track ID:', error);
            return null;
        }
    }

    // Generate SoundCloud URL
    static generateUrl(trackPermalink) {
        return trackPermalink;
    }

    // Resolve SoundCloud URL to track data
    async resolveUrl(url) {
        try {
            const token = await this.getAccessToken();
            
            const params = new URLSearchParams({
                url: url
            });

            const response = await fetch(`${this.baseUrl}/resolve?${params}`, {
                headers: {
                    'Authorization': `OAuth ${token}`
                }
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('SoundCloud resolve response:', response.status, errorText);
                throw new Error(`SoundCloud resolve failed: ${response.status}`);
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('SoundCloud resolve error:', error);
            throw error;
        }
    }

    // Search for tracks
    async searchTracks(query, limit = 20) {
        try {
            const token = await this.getAccessToken();
            
            const params = new URLSearchParams({
                q: query,
                limit: limit
            });

            const response = await fetch(`${this.baseUrl}/tracks?${params}`, {
                headers: {
                    'Authorization': `OAuth ${token}`
                }
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('SoundCloud search response:', response.status, errorText);
                throw new Error(`SoundCloud search failed: ${response.status}`);
            }

            const data = await response.json();
            console.log('SoundCloud search data structure:', JSON.stringify(data).substring(0, 500));
            return data.collection || data || [];

        } catch (error) {
            console.error('SoundCloud search error:', error);
            throw error;
        }
    }

    // Get track by ID
    async getTrack(trackId) {
        try {
            const token = await this.getAccessToken();

            const response = await fetch(`${this.baseUrl}/tracks/${trackId}`, {
                headers: {
                    'Authorization': `OAuth ${token}`
                }
            });

            if (!response.ok) {
                const errorText = await response.text();
                console.error('SoundCloud get track response:', response.status, errorText);
                throw new Error(`Track not found: ${response.status}`);
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('SoundCloud get track error:', error);
            throw error;
        }
    }
}

export default SoundCloudAPI;

