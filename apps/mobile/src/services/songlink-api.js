// SongLink/Odesli API Service
// Used specifically for Amazon Music conversions
class SongLinkAPI {
    constructor() {
        this.baseUrl = 'https://api.song.link/v1-alpha.1';
    }

    // Get all platform links for a given music URL
    async getLinks(musicUrl) {
        try {
            const params = new URLSearchParams({
                url: musicUrl,
                userCountry: 'US'
            });

            const response = await fetch(`${this.baseUrl}/links?${params}`);

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.message || 'SongLink API request failed');
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('SongLink API error:', error);
            throw error;
        }
    }

    // Extract Amazon Music link from SongLink response
    static extractAmazonLink(songLinkData) {
        // Check for Amazon Music link
        const amazonLinks = songLinkData.linksByPlatform?.amazonMusic;
        if (amazonLinks && amazonLinks.url) {
            return amazonLinks.url;
        }

        // Alternative: check in entities
        const entities = songLinkData.entitiesByUniqueId;
        if (entities) {
            for (const key in entities) {
                const entity = entities[key];
                if (entity.apiProvider === 'amazon' || key.includes('AMAZON')) {
                    if (entity.url) return entity.url;
                }
            }
        }

        return null;
    }

    // Extract specific platform link from SongLink response
    static extractPlatformLink(songLinkData, platform) {
        const platformMap = {
            'spotify': 'spotify',
            'apple': 'appleMusic',
            'youtube': 'youtube',
            'youtubeMusic': 'youtubeMusic',
            'amazon': 'amazonMusic',
            'tidal': 'tidal',
            'soundcloud': 'soundcloud'
        };

        const platformKey = platformMap[platform];
        if (!platformKey) return null;

        const platformLinks = songLinkData.linksByPlatform?.[platformKey];
        if (platformLinks && platformLinks.url) {
            return platformLinks.url;
        }

        return null;
    }

    // Extract Tidal link from SongLink response
    static extractTidalLink(songLinkData) {
        const tidalLinks = songLinkData.linksByPlatform?.tidal;
        if (tidalLinks && tidalLinks.url) {
            return tidalLinks.url;
        }
        return null;
    }
}

export default SongLinkAPI;

