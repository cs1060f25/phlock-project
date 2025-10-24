// YouTube Data API v3 Service
import { CONFIG } from './config';

class YouTubeAPI {
    constructor() {
        this.apiKey = CONFIG.YOUTUBE_API_KEY;
        this.baseUrl = 'https://www.googleapis.com/youtube/v3';
    }

    // Extract video ID from YouTube or YouTube Music URL
    static extractVideoId(url) {
        try {
            const urlObj = new URL(url);
            
            // YouTube Music: music.youtube.com/watch?v=VIDEO_ID
            if (urlObj.hostname === 'music.youtube.com') {
                return urlObj.searchParams.get('v');
            }
            
            // YouTube: youtube.com/watch?v=VIDEO_ID
            if (urlObj.hostname === 'www.youtube.com' || urlObj.hostname === 'youtube.com') {
                return urlObj.searchParams.get('v');
            }
            
            // Short URL: youtu.be/VIDEO_ID
            if (urlObj.hostname === 'youtu.be') {
                return urlObj.pathname.slice(1);
            }
            
            return null;
        } catch (error) {
            console.error('Error extracting YouTube video ID:', error);
            return null;
        }
    }

    // Generate YouTube URL
    static generateUrl(videoId, isMusic = false) {
        if (isMusic) {
            return `https://music.youtube.com/watch?v=${videoId}`;
        }
        return `https://www.youtube.com/watch?v=${videoId}`;
    }

    // Search for videos
    async searchVideos(query, maxResults = 10, videoCategoryId = '10') {
        try {
            // videoCategoryId 10 = Music category
            const params = new URLSearchParams({
                part: 'snippet',
                q: query,
                type: 'video',
                videoCategoryId: videoCategoryId,
                maxResults: maxResults,
                key: this.apiKey
            });

            const response = await fetch(`${this.baseUrl}/search?${params}`);
            
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error?.message || 'YouTube API request failed');
            }

            const data = await response.json();
            
            // Get video details for duration and additional info
            if (data.items && data.items.length > 0) {
                const videoIds = data.items.map(item => item.id.videoId).join(',');
                return await this.getVideoDetails(videoIds);
            }

            return [];

        } catch (error) {
            console.error('YouTube search error:', error);
            throw error;
        }
    }

    // Get video details by ID(s)
    async getVideoDetails(videoIds) {
        try {
            const params = new URLSearchParams({
                part: 'snippet,contentDetails,statistics',
                id: videoIds,
                key: this.apiKey
            });

            const response = await fetch(`${this.baseUrl}/videos?${params}`);
            
            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error?.message || 'YouTube API request failed');
            }

            const data = await response.json();
            return data.items || [];

        } catch (error) {
            console.error('YouTube get video details error:', error);
            throw error;
        }
    }

    // Get single video by ID
    async getVideo(videoId) {
        try {
            const videos = await this.getVideoDetails(videoId);
            if (videos.length === 0) {
                throw new Error('Video not found');
            }
            return videos[0];
        } catch (error) {
            console.error('YouTube get video error:', error);
            throw error;
        }
    }

    // Parse ISO 8601 duration to milliseconds
    static parseDuration(duration) {
        // Duration format: PT#H#M#S or PT#M#S or PT#S
        const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
        if (!match) return 0;

        const hours = parseInt(match[1] || '0');
        const minutes = parseInt(match[2] || '0');
        const seconds = parseInt(match[3] || '0');

        return (hours * 3600 + minutes * 60 + seconds) * 1000;
    }

    // Extract artist and title from video title
    static parseTitle(title) {
        // Common patterns: "Artist - Title", "Title - Artist", "Artist: Title"
        // Also handle "(Official Video)", "[Official Music Video]", etc.
        
        // Remove common suffixes
        let cleaned = title
            .replace(/\s*\(Official.*?\)/gi, '')
            .replace(/\s*\[Official.*?\]/gi, '')
            .replace(/\s*\(Lyric.*?\)/gi, '')
            .replace(/\s*\[Lyric.*?\]/gi, '')
            .replace(/\s*\(Audio\)/gi, '')
            .replace(/\s*\[Audio\]/gi, '')
            .replace(/\s*\(Video\)/gi, '')
            .replace(/\s*\[Video\]/gi, '')
            .trim();

        // Try to split by common delimiters
        let artist = '';
        let songTitle = '';

        if (cleaned.includes(' - ')) {
            const parts = cleaned.split(' - ');
            artist = parts[0].trim();
            songTitle = parts[1].trim();
        } else if (cleaned.includes(' – ')) {
            const parts = cleaned.split(' – ');
            artist = parts[0].trim();
            songTitle = parts[1].trim();
        } else if (cleaned.includes(': ')) {
            const parts = cleaned.split(': ');
            artist = parts[0].trim();
            songTitle = parts[1].trim();
        } else {
            // If no delimiter, use channel name as artist and title as song
            songTitle = cleaned;
        }

        return { artist, title: songTitle || cleaned };
    }
}

export default YouTubeAPI;

