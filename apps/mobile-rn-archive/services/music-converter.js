// Music Link Converter Service
import SpotifyAPI from './spotify-api';
import AppleMusicAPI from './apple-music-api';
import YouTubeAPI from './youtube-api';
import SongLinkAPI from './songlink-api';
import TidalAPI from './tidal-api';
import SoundCloudAPI from './soundcloud-api';

class MusicConverter {
    constructor() {
        this.spotify = new SpotifyAPI();
        this.appleMusic = new AppleMusicAPI();
        this.youtube = new YouTubeAPI();
        this.songlink = new SongLinkAPI();
        this.tidal = new TidalAPI();
        this.soundcloud = new SoundCloudAPI();
    }

    // Normalize track data for comparison
    normalizeTrackData(track, platform) {
        if (platform === 'spotify') {
            return {
                title: track.name,
                artist: track.artists[0]?.name,
                album: track.album?.name,
                duration: track.duration_ms,
                platform: 'spotify',
                id: track.id
            };
        } else if (platform === 'apple') {
            return {
                title: track.attributes?.name,
                artist: track.attributes?.artistName,
                album: track.attributes?.albumName,
                duration: track.attributes?.durationInMillis,
                platform: 'apple',
                id: track.id
            };
        } else if (platform === 'youtube' || platform === 'youtubeMusic') {
            const parsed = YouTubeAPI.parseTitle(track.snippet?.title || '');
            return {
                title: parsed.title,
                artist: parsed.artist || track.snippet?.channelTitle,
                album: null,
                duration: YouTubeAPI.parseDuration(track.contentDetails?.duration || 'PT0S'),
                platform: platform,
                id: track.id
            };
        } else if (platform === 'amazon') {
            return {
                title: track.name || track.title,
                artist: track.artists?.[0]?.name || track.artist,
                album: track.album?.name || track.albumName,
                duration: track.durationMs || track.duration,
                platform: 'amazon',
                id: track.id || track.asin
            };
        } else if (platform === 'tidal') {
            return {
                title: track.title || track.name,
                artist: track.artist?.name || track.artists?.[0]?.name || track.artist,
                album: track.album?.title || track.album?.name || track.albumName,
                duration: track.duration ? track.duration * 1000 : track.durationMs,
                platform: 'tidal',
                id: track.id
            };
        } else if (platform === 'soundcloud') {
            return {
                title: track.title,
                artist: track.user?.username || track.publisher_metadata?.artist || 'Unknown',
                album: null,
                duration: track.duration || track.full_duration,
                platform: 'soundcloud',
                id: track.id,
                permalink: track.permalink_url
            };
        }
        return null;
    }

    // Calculate similarity score between two tracks
    calculateSimilarity(track1, track2) {
        let score = 0;
        
        // Title similarity (most important)
        if (track1.title && track2.title) {
            const title1 = track1.title.toLowerCase().trim();
            const title2 = track2.title.toLowerCase().trim();
            if (title1 === title2) {
                score += 40;
            } else if (title1.includes(title2) || title2.includes(title1)) {
                score += 30;
            } else {
                // Simple word overlap check
                const words1 = title1.split(/\s+/);
                const words2 = title2.split(/\s+/);
                const commonWords = words1.filter(word => words2.includes(word));
                score += (commonWords.length / Math.max(words1.length, words2.length)) * 25;
            }
        }

        // Artist similarity
        if (track1.artist && track2.artist) {
            const artist1 = track1.artist.toLowerCase().trim();
            const artist2 = track2.artist.toLowerCase().trim();
            if (artist1 === artist2) {
                score += 35;
            } else if (artist1.includes(artist2) || artist2.includes(artist1)) {
                score += 25;
            }
        }

        // Album similarity
        if (track1.album && track2.album) {
            const album1 = track1.album.toLowerCase().trim();
            const album2 = track2.album.toLowerCase().trim();
            if (album1 === album2) {
                score += 20;
            } else if (album1.includes(album2) || album2.includes(album1)) {
                score += 10;
            }
        }

        // Duration similarity (within 5 seconds)
        if (track1.duration && track2.duration) {
            const duration1 = track1.duration;
            const duration2 = track2.duration;
            const diff = Math.abs(duration1 - duration2);
            if (diff < 5000) { // 5 seconds
                score += 5;
            }
        }

        return Math.min(score, 100); // Cap at 100
    }

    // Convert Spotify track to Apple Music
    async convertSpotifyToApple(spotifyUrl) {
        try {
            // Extract track ID
            const trackId = SpotifyAPI.extractTrackId(spotifyUrl);
            if (!trackId) {
                throw new Error('Invalid Spotify URL');
            }

            // Get track details from Spotify
            const spotifyTrack = await this.spotify.getTrack(trackId);
            const normalizedSpotify = this.normalizeTrackData(spotifyTrack, 'spotify');

            // Search for matching track on Apple Music
            const searchQuery = `${normalizedSpotify.title} ${normalizedSpotify.artist}`;
            const appleResults = await this.appleMusic.searchSongs(searchQuery, 20);

            if (appleResults.length === 0) {
                throw new Error('No matching track found on Apple Music');
            }

            // Find best match
            let bestMatch = null;
            let bestScore = 0;

            for (const appleTrack of appleResults) {
                const normalizedApple = this.normalizeTrackData(appleTrack, 'apple');
                const score = this.calculateSimilarity(normalizedSpotify, normalizedApple);
                
                if (score > bestScore && score > 60) { // Minimum 60% similarity
                    bestScore = score;
                    bestMatch = appleTrack;
                }
            }

            if (!bestMatch) {
                throw new Error('No sufficiently similar track found on Apple Music');
            }

            // Generate Apple Music URL
            console.log('Apple Music track data:', JSON.stringify(bestMatch, null, 2));

            // Extract album ID from the track's URL if available
            let albumId = bestMatch.attributes?.albumId || bestMatch.relationships?.albums?.data?.[0]?.id;

            if (!albumId && bestMatch.attributes?.url) {
                // Extract from URL like: https://music.apple.com/us/album/album-name/1829577315?i=1829577317
                const urlMatch = bestMatch.attributes.url.match(/\/album\/[^\/]+\/(\d+)\?i=/);
                if (urlMatch) {
                    albumId = urlMatch[1];
                }
            }

            console.log('Album ID found:', albumId);
            
            const appleUrl = AppleMusicAPI.generateUrlWithAlbum(
                bestMatch.id,
                albumId,
                'us'
            );

            return {
                success: true,
                originalUrl: spotifyUrl,
                convertedUrl: appleUrl,
                originalPlatform: 'Spotify',
                targetPlatform: 'Apple Music',
                confidence: bestScore,
                track: {
                    title: normalizedSpotify.title,
                    artist: normalizedSpotify.artist,
                    album: normalizedSpotify.album
                }
            };

        } catch (error) {
            console.error('Spotify to Apple Music conversion error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert Apple Music track to Spotify
    async convertAppleToSpotify(appleUrl) {
        try {
            // Extract track ID
            console.log('Converting Apple Music URL:', appleUrl);
            const trackId = AppleMusicAPI.extractTrackId(appleUrl);
            console.log('Extracted track ID:', trackId);
            
            if (!trackId) {
                console.error('Failed to extract track ID from URL:', appleUrl);
                throw new Error('Invalid Apple Music URL');
            }

            // Get track details from Apple Music
            const appleTrack = await this.appleMusic.getTrack(trackId);
            const normalizedApple = this.normalizeTrackData(appleTrack, 'apple');

            // Search for matching track on Spotify
            const searchQuery = `${normalizedApple.title} ${normalizedApple.artist}`;
            const spotifyResults = await this.spotify.searchTracks(searchQuery, 20);

            if (spotifyResults.length === 0) {
                throw new Error('No matching track found on Spotify');
            }

            // Find best match
            let bestMatch = null;
            let bestScore = 0;

            for (const spotifyTrack of spotifyResults) {
                const normalizedSpotify = this.normalizeTrackData(spotifyTrack, 'spotify');
                const score = this.calculateSimilarity(normalizedApple, normalizedSpotify);
                
                if (score > bestScore && score > 60) { // Minimum 60% similarity
                    bestScore = score;
                    bestMatch = spotifyTrack;
                }
            }

            if (!bestMatch) {
                throw new Error('No sufficiently similar track found on Spotify');
            }

            // Generate Spotify URL
            const spotifyUrl = SpotifyAPI.generateUrl(bestMatch.id);

            return {
                success: true,
                originalUrl: appleUrl,
                convertedUrl: spotifyUrl,
                originalPlatform: 'Apple Music',
                targetPlatform: 'Spotify',
                confidence: bestScore,
                track: {
                    title: normalizedApple.title,
                    artist: normalizedApple.artist,
                    album: normalizedApple.album
                }
            };

        } catch (error) {
            console.error('Apple Music to Spotify conversion error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert any platform to YouTube (or YouTube Music)
    async convertToYouTube(sourceUrl, sourcePlatform, isYouTubeMusic = false) {
        try {
            let searchQuery = '';
            let sourceTrack = null;

            // Get track info from source platform
            if (sourcePlatform === 'spotify') {
                const trackId = SpotifyAPI.extractTrackId(sourceUrl);
                const spotifyTrack = await this.spotify.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
                searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            } else if (sourcePlatform === 'apple') {
                const trackId = AppleMusicAPI.extractTrackId(sourceUrl);
                const appleTrack = await this.appleMusic.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(appleTrack, 'apple');
                searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            } else if (sourcePlatform === 'youtube' || sourcePlatform === 'youtubeMusic') {
                const videoId = YouTubeAPI.extractVideoId(sourceUrl);
                const youtubeVideo = await this.youtube.getVideo(videoId);
                sourceTrack = this.normalizeTrackData(youtubeVideo, sourcePlatform);
                searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            }

            // Search YouTube
            const youtubeResults = await this.youtube.searchVideos(searchQuery, 20);

            if (youtubeResults.length === 0) {
                throw new Error('No matching video found on YouTube');
            }

            // Find best match
            let bestMatch = null;
            let bestScore = 0;

            for (const youtubeVideo of youtubeResults) {
                const normalizedYouTube = this.normalizeTrackData(youtubeVideo, isYouTubeMusic ? 'youtubeMusic' : 'youtube');
                const score = this.calculateSimilarity(sourceTrack, normalizedYouTube);
                
                if (score > bestScore && score > 60) {
                    bestScore = score;
                    bestMatch = youtubeVideo;
                }
            }

            if (!bestMatch) {
                throw new Error('No sufficiently similar video found on YouTube');
            }

            const youtubeUrl = YouTubeAPI.generateUrl(bestMatch.id, isYouTubeMusic);
            const platformName = isYouTubeMusic ? 'YouTube Music' : 'YouTube';

            return {
                success: true,
                originalUrl: sourceUrl,
                convertedUrl: youtubeUrl,
                originalPlatform: sourcePlatform,
                targetPlatform: platformName,
                confidence: bestScore,
                track: {
                    title: sourceTrack.title,
                    artist: sourceTrack.artist,
                    album: sourceTrack.album
                }
            };

        } catch (error) {
            console.error('Convert to YouTube error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert YouTube to another platform
    async convertFromYouTube(youtubeUrl, targetPlatform, sourceIsYouTubeMusic = false) {
        try {
            const videoId = YouTubeAPI.extractVideoId(youtubeUrl);
            const youtubeVideo = await this.youtube.getVideo(videoId);
            const sourceTrack = this.normalizeTrackData(youtubeVideo, sourceIsYouTubeMusic ? 'youtubeMusic' : 'youtube');

            const searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            let targetResults = [];
            let bestMatch = null;
            let bestScore = 0;

            if (targetPlatform === 'spotify') {
                targetResults = await this.spotify.searchTracks(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'spotify');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Spotify');
                }

                const spotifyUrl = SpotifyAPI.generateUrl(bestMatch.id);

                return {
                    success: true,
                    originalUrl: youtubeUrl,
                    convertedUrl: spotifyUrl,
                    originalPlatform: sourceIsYouTubeMusic ? 'YouTube Music' : 'YouTube',
                    targetPlatform: 'Spotify',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };

            } else if (targetPlatform === 'apple') {
                targetResults = await this.appleMusic.searchSongs(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'apple');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Apple Music');
                }

                // Extract album ID from the track's URL if available
                let albumId = bestMatch.attributes?.albumId || bestMatch.relationships?.albums?.data?.[0]?.id;
                if (!albumId && bestMatch.attributes?.url) {
                    const urlMatch = bestMatch.attributes.url.match(/\/album\/[^\/]+\/(\d+)\?i=/);
                    if (urlMatch) {
                        albumId = urlMatch[1];
                    }
                }

                const appleUrl = AppleMusicAPI.generateUrlWithAlbum(bestMatch.id, albumId, 'us');

                return {
                    success: true,
                    originalUrl: youtubeUrl,
                    convertedUrl: appleUrl,
                    originalPlatform: sourceIsYouTubeMusic ? 'YouTube Music' : 'YouTube',
                    targetPlatform: 'Apple Music',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };
            }

        } catch (error) {
            console.error('Convert from YouTube error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert to Amazon Music from any platform using SongLink
    async convertToAmazon(sourceUrl, sourcePlatform) {
        try {
            // Use SongLink API to get Amazon Music link
            const songLinkData = await this.songlink.getLinks(sourceUrl);
            const amazonUrl = SongLinkAPI.extractAmazonLink(songLinkData);

            if (!amazonUrl) {
                throw new Error('No Amazon Music link found for this track');
            }

            // Get track info for display
            let sourceTrack = { title: '', artist: '', album: '' };
            
            if (sourcePlatform === 'spotify') {
                const trackId = SpotifyAPI.extractTrackId(sourceUrl);
                const spotifyTrack = await this.spotify.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
            } else if (sourcePlatform === 'apple') {
                const trackId = AppleMusicAPI.extractTrackId(sourceUrl);
                const appleTrack = await this.appleMusic.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(appleTrack, 'apple');
            } else if (sourcePlatform === 'youtube' || sourcePlatform === 'youtubeMusic') {
                const videoId = YouTubeAPI.extractVideoId(sourceUrl);
                const youtubeVideo = await this.youtube.getVideo(videoId);
                sourceTrack = this.normalizeTrackData(youtubeVideo, sourcePlatform);
            }

            return {
                success: true,
                originalUrl: sourceUrl,
                convertedUrl: amazonUrl,
                originalPlatform: sourcePlatform,
                targetPlatform: 'Amazon Music',
                confidence: 95,
                track: {
                    title: sourceTrack.title,
                    artist: sourceTrack.artist,
                    album: sourceTrack.album
                }
            };

        } catch (error) {
            console.error('Convert to Amazon Music error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert from Amazon Music to other platforms using SongLink
    async convertFromAmazon(amazonUrl, targetPlatform) {
        try {
            // Use SongLink API to get all platform links
            const songLinkData = await this.songlink.getLinks(amazonUrl);
            const targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, targetPlatform);

            if (!targetUrl) {
                throw new Error(`No ${this.getPlatformName(targetPlatform)} link found for this track`);
            }

            // Try to get track info from the target platform for display
            let trackInfo = { title: '', artist: '', album: '' };
            
            try {
                if (targetPlatform === 'spotify') {
                    const trackId = SpotifyAPI.extractTrackId(targetUrl);
                    const track = await this.spotify.getTrack(trackId);
                    trackInfo = this.normalizeTrackData(track, 'spotify');
                } else if (targetPlatform === 'apple') {
                    const trackId = AppleMusicAPI.extractTrackId(targetUrl);
                    const track = await this.appleMusic.getTrack(trackId);
                    trackInfo = this.normalizeTrackData(track, 'apple');
                } else if (targetPlatform === 'youtube' || targetPlatform === 'youtubeMusic') {
                    const videoId = YouTubeAPI.extractVideoId(targetUrl);
                    const video = await this.youtube.getVideo(videoId);
                    trackInfo = this.normalizeTrackData(video, targetPlatform);
                }
            } catch (err) {
                console.log('Could not get track info, using defaults');
            }

            return {
                success: true,
                originalUrl: amazonUrl,
                convertedUrl: targetUrl,
                originalPlatform: 'Amazon Music',
                targetPlatform: this.getPlatformName(targetPlatform),
                confidence: 95,
                track: {
                    title: trackInfo.title,
                    artist: trackInfo.artist,
                    album: trackInfo.album
                }
            };

        } catch (error) {
            console.error('Convert from Amazon Music error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert to Tidal from any platform
    async convertToTidal(sourceUrl, sourcePlatform) {
        try {
            // Use SongLink API to get Tidal link
            const songLinkData = await this.songlink.getLinks(sourceUrl);
            const tidalUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'tidal');

            if (!tidalUrl) {
                throw new Error('Tidal link not available for this track');
            }

            // Get track info for display
            let sourceTrack = { title: '', artist: '', album: '' };
            
            if (sourcePlatform === 'spotify') {
                const trackId = SpotifyAPI.extractTrackId(sourceUrl);
                const spotifyTrack = await this.spotify.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
            } else if (sourcePlatform === 'apple') {
                const trackId = AppleMusicAPI.extractTrackId(sourceUrl);
                const appleTrack = await this.appleMusic.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(appleTrack, 'apple');
            } else if (sourcePlatform === 'youtube' || sourcePlatform === 'youtubeMusic') {
                const videoId = YouTubeAPI.extractVideoId(sourceUrl);
                const youtubeVideo = await this.youtube.getVideo(videoId);
                sourceTrack = this.normalizeTrackData(youtubeVideo, sourcePlatform);
            } else if (sourcePlatform === 'amazon') {
                const spotifyUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'spotify');
                if (spotifyUrl) {
                    const trackId = SpotifyAPI.extractTrackId(spotifyUrl);
                    const spotifyTrack = await this.spotify.getTrack(trackId);
                    sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
                }
            }

            return {
                success: true,
                originalUrl: sourceUrl,
                convertedUrl: tidalUrl,
                originalPlatform: sourcePlatform,
                targetPlatform: 'Tidal',
                confidence: 95,
                track: {
                    title: sourceTrack.title || 'Unknown',
                    artist: sourceTrack.artist || 'Unknown',
                    album: sourceTrack.album || 'Unknown'
                }
            };

        } catch (error) {
            console.error('Convert to Tidal error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert from Tidal to other platforms
    async convertFromTidal(tidalUrl, targetPlatform) {
        try {
            // Use SongLink API to get target platform link
            const songLinkData = await this.songlink.getLinks(tidalUrl);
            
            let targetUrl = null;
            if (targetPlatform === 'spotify') {
                targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'spotify');
            } else if (targetPlatform === 'apple') {
                targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'appleMusic');
            } else if (targetPlatform === 'youtube') {
                targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'youtube');
            } else if (targetPlatform === 'youtubeMusic') {
                targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'youtubeMusic');
            } else if (targetPlatform === 'amazon') {
                targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'amazonMusic');
            }
            
            if (!targetUrl) {
                throw new Error(`${this.getPlatformName(targetPlatform)} link not available for this track`);
            }

            // Get track info for display from Spotify link (most reliable)
            const spotifyUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'spotify');
            let trackInfo = { title: 'Unknown', artist: 'Unknown', album: 'Unknown' };
            
            if (spotifyUrl) {
                try {
                    const trackId = SpotifyAPI.extractTrackId(spotifyUrl);
                    const spotifyTrack = await this.spotify.getTrack(trackId);
                    const normalized = this.normalizeTrackData(spotifyTrack, 'spotify');
                    trackInfo = {
                        title: normalized.title,
                        artist: normalized.artist,
                        album: normalized.album
                    };
                } catch (e) {
                    console.error('Could not fetch track info:', e);
                }
            }
            
            return {
                success: true,
                originalUrl: tidalUrl,
                convertedUrl: targetUrl,
                originalPlatform: 'Tidal',
                targetPlatform: this.getPlatformName(targetPlatform),
                confidence: 95,
                track: trackInfo
            };

        } catch (error) {
            console.error('Convert from Tidal error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert to SoundCloud from any platform
    async convertToSoundCloud(sourceUrl, sourcePlatform) {
        try {
            // Get track info from source
            let sourceTrack = null;
            
            if (sourcePlatform === 'spotify') {
                const trackId = SpotifyAPI.extractTrackId(sourceUrl);
                const spotifyTrack = await this.spotify.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
            } else if (sourcePlatform === 'apple') {
                const trackId = AppleMusicAPI.extractTrackId(sourceUrl);
                const appleTrack = await this.appleMusic.getTrack(trackId);
                sourceTrack = this.normalizeTrackData(appleTrack, 'apple');
            } else if (sourcePlatform === 'youtube' || sourcePlatform === 'youtubeMusic') {
                const videoId = YouTubeAPI.extractVideoId(sourceUrl);
                const youtubeVideo = await this.youtube.getVideo(videoId);
                sourceTrack = this.normalizeTrackData(youtubeVideo, sourcePlatform);
            } else if (sourcePlatform === 'amazon' || sourcePlatform === 'tidal') {
                // Use SongLink for Amazon/Tidal first to get Spotify link
                const songLinkData = await this.songlink.getLinks(sourceUrl);
                const spotifyUrl = SongLinkAPI.extractPlatformLink(songLinkData, 'spotify');
                if (spotifyUrl) {
                    const trackId = SpotifyAPI.extractTrackId(spotifyUrl);
                    const spotifyTrack = await this.spotify.getTrack(trackId);
                    sourceTrack = this.normalizeTrackData(spotifyTrack, 'spotify');
                }
            }

            if (!sourceTrack) {
                throw new Error('Could not get track info from source');
            }

            // Search SoundCloud
            const searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            const soundcloudResults = await this.soundcloud.searchTracks(searchQuery, 20);

            if (soundcloudResults.length === 0) {
                throw new Error('No matching track found on SoundCloud');
            }

            let bestMatch = null;
            let bestScore = 0;

            for (const track of soundcloudResults) {
                const normalized = this.normalizeTrackData(track, 'soundcloud');
                const score = this.calculateSimilarity(sourceTrack, normalized);
                
                if (score > bestScore && score > 60) {
                    bestScore = score;
                    bestMatch = track;
                }
            }

            if (!bestMatch) {
                throw new Error('No sufficiently similar track found on SoundCloud');
            }

            return {
                success: true,
                originalUrl: sourceUrl,
                convertedUrl: bestMatch.permalink_url,
                originalPlatform: sourcePlatform,
                targetPlatform: 'SoundCloud',
                confidence: bestScore,
                track: {
                    title: sourceTrack.title,
                    artist: sourceTrack.artist,
                    album: sourceTrack.album
                }
            };

        } catch (error) {
            console.error('Convert to SoundCloud error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Convert from SoundCloud to other platforms
    async convertFromSoundCloud(soundcloudUrl, targetPlatform) {
        try {
            // Resolve SoundCloud URL to get track data
            const soundcloudTrack = await this.soundcloud.resolveUrl(soundcloudUrl);
            const sourceTrack = this.normalizeTrackData(soundcloudTrack, 'soundcloud');

            const searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            let targetResults = [];
            let bestMatch = null;
            let bestScore = 0;

            if (targetPlatform === 'spotify') {
                targetResults = await this.spotify.searchTracks(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'spotify');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Spotify');
                }

                return {
                    success: true,
                    originalUrl: soundcloudUrl,
                    convertedUrl: SpotifyAPI.generateUrl(bestMatch.id),
                    originalPlatform: 'SoundCloud',
                    targetPlatform: 'Spotify',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };

            } else if (targetPlatform === 'apple') {
                targetResults = await this.appleMusic.searchSongs(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'apple');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Apple Music');
                }

                // Extract album ID from the track's URL if available
                let albumId = bestMatch.attributes?.albumId || bestMatch.relationships?.albums?.data?.[0]?.id;
                if (!albumId && bestMatch.attributes?.url) {
                    const urlMatch = bestMatch.attributes.url.match(/\/album\/[^\/]+\/(\d+)\?i=/);
                    if (urlMatch) {
                        albumId = urlMatch[1];
                    }
                }

                return {
                    success: true,
                    originalUrl: soundcloudUrl,
                    convertedUrl: AppleMusicAPI.generateUrlWithAlbum(bestMatch.id, albumId, 'us'),
                    originalPlatform: 'SoundCloud',
                    targetPlatform: 'Apple Music',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };

            } else if (targetPlatform === 'youtube' || targetPlatform === 'youtubeMusic') {
                targetResults = await this.youtube.searchVideos(searchQuery, 20);
                
                for (const video of targetResults) {
                    const normalized = this.normalizeTrackData(video, targetPlatform);
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = video;
                    }
                }

                if (!bestMatch) {
                    throw new Error(`No sufficiently similar track found on ${targetPlatform === 'youtubeMusic' ? 'YouTube Music' : 'YouTube'}`);
                }

                return {
                    success: true,
                    originalUrl: soundcloudUrl,
                    convertedUrl: YouTubeAPI.generateUrl(bestMatch.id, targetPlatform === 'youtubeMusic'),
                    originalPlatform: 'SoundCloud',
                    targetPlatform: targetPlatform === 'youtubeMusic' ? 'YouTube Music' : 'YouTube',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };
            } else if (targetPlatform === 'amazon' || targetPlatform === 'tidal') {
                // Use SongLink for SoundCloud → Amazon/Tidal
                const songLinkData = await this.songlink.getLinks(soundcloudUrl);
                const targetUrl = SongLinkAPI.extractPlatformLink(songLinkData, targetPlatform === 'amazon' ? 'amazonMusic' : 'tidal');

                if (!targetUrl) {
                    throw new Error(`No ${this.getPlatformName(targetPlatform)} link found for this track`);
                }

                return {
                    success: true,
                    originalUrl: soundcloudUrl,
                    convertedUrl: targetUrl,
                    originalPlatform: 'SoundCloud',
                    targetPlatform: this.getPlatformName(targetPlatform),
                    confidence: 95,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };
            }

            throw new Error(`Unsupported target platform: ${targetPlatform}`);

        } catch (error) {
            console.error('Convert from SoundCloud error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Old complex implementation - keeping for reference
    async convertFromTidalOld(tidalUrl, targetPlatform) {
        try {
            const trackId = TidalAPI.extractTrackId(tidalUrl);
            const tidalTrack = await this.tidal.getTrack(trackId);
            const sourceTrack = this.normalizeTrackData(tidalTrack, 'tidal');

            const searchQuery = `${sourceTrack.artist} ${sourceTrack.title}`;
            let targetResults = [];
            let bestMatch = null;
            let bestScore = 0;

            if (targetPlatform === 'spotify') {
                targetResults = await this.spotify.searchTracks(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'spotify');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Spotify');
                }

                return {
                    success: true,
                    originalUrl: tidalUrl,
                    convertedUrl: SpotifyAPI.generateUrl(bestMatch.id),
                    originalPlatform: 'Tidal',
                    targetPlatform: 'Spotify',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };

            } else if (targetPlatform === 'apple') {
                targetResults = await this.appleMusic.searchSongs(searchQuery, 20);
                
                for (const track of targetResults) {
                    const normalized = this.normalizeTrackData(track, 'apple');
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = track;
                    }
                }

                if (!bestMatch) {
                    throw new Error('No sufficiently similar track found on Apple Music');
                }

                // Extract album ID from the track's URL if available
                let albumId = bestMatch.attributes?.albumId || bestMatch.relationships?.albums?.data?.[0]?.id;
                if (!albumId && bestMatch.attributes?.url) {
                    const urlMatch = bestMatch.attributes.url.match(/\/album\/[^\/]+\/(\d+)\?i=/);
                    if (urlMatch) {
                        albumId = urlMatch[1];
                    }
                }

                return {
                    success: true,
                    originalUrl: tidalUrl,
                    convertedUrl: AppleMusicAPI.generateUrlWithAlbum(bestMatch.id, albumId, 'us'),
                    originalPlatform: 'Tidal',
                    targetPlatform: 'Apple Music',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };

            } else if (targetPlatform === 'youtube' || targetPlatform === 'youtubeMusic') {
                targetResults = await this.youtube.searchVideos(searchQuery, 20);
                
                for (const video of targetResults) {
                    const normalized = this.normalizeTrackData(video, targetPlatform);
                    const score = this.calculateSimilarity(sourceTrack, normalized);
                    
                    if (score > bestScore && score > 60) {
                        bestScore = score;
                        bestMatch = video;
                    }
                }

                if (!bestMatch) {
                    throw new Error(`No sufficiently similar track found on ${targetPlatform === 'youtubeMusic' ? 'YouTube Music' : 'YouTube'}`);
                }

                return {
                    success: true,
                    originalUrl: tidalUrl,
                    convertedUrl: YouTubeAPI.generateUrl(bestMatch.id, targetPlatform === 'youtubeMusic'),
                    originalPlatform: 'Tidal',
                    targetPlatform: targetPlatform === 'youtubeMusic' ? 'YouTube Music' : 'YouTube',
                    confidence: bestScore,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };
            } else if (targetPlatform === 'amazon') {
                // Use SongLink for Tidal → Amazon
                const songLinkData = await this.songlink.getLinks(tidalUrl);
                const amazonUrl = SongLinkAPI.extractAmazonLink(songLinkData);

                if (!amazonUrl) {
                    throw new Error('No Amazon Music link found for this track');
                }

                return {
                    success: true,
                    originalUrl: tidalUrl,
                    convertedUrl: amazonUrl,
                    originalPlatform: 'Tidal',
                    targetPlatform: 'Amazon Music',
                    confidence: 95,
                    track: {
                        title: sourceTrack.title,
                        artist: sourceTrack.artist,
                        album: sourceTrack.album
                    }
                };
            }

        } catch (error) {
            console.error('Convert from Tidal error:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Helper to get platform display name
    getPlatformName(platform) {
        const names = {
            'spotify': 'Spotify',
            'apple': 'Apple Music',
            'youtube': 'YouTube',
            'youtubeMusic': 'YouTube Music',
            'amazon': 'Amazon Music',
            'tidal': 'Tidal',
            'soundcloud': 'SoundCloud'
        };
        return names[platform] || platform;
    }

    // Main conversion method
    async convert(url, targetPlatform) {
        try {
            // Detect source platform
            const sourcePlatform = this.detectPlatform(url);
            
            if (!sourcePlatform) {
                throw new Error('Unsupported music platform URL');
            }

            if (sourcePlatform === targetPlatform) {
                throw new Error('Source and target platforms are the same');
            }

            // Handle conversions TO Tidal
            if (targetPlatform === 'tidal') {
                return await this.convertToTidal(url, sourcePlatform);
            }

            // Handle conversions FROM Tidal
            if (sourcePlatform === 'tidal') {
                return await this.convertFromTidal(url, targetPlatform);
            }

            // Handle conversions TO Amazon Music
            if (targetPlatform === 'amazon') {
                return await this.convertToAmazon(url, sourcePlatform);
            }

            // Handle conversions FROM Amazon Music
            if (sourcePlatform === 'amazon') {
                return await this.convertFromAmazon(url, targetPlatform);
            }

            // Handle conversions TO YouTube or YouTube Music
            if (targetPlatform === 'youtube') {
                return await this.convertToYouTube(url, sourcePlatform, false);
            } else if (targetPlatform === 'youtubeMusic') {
                return await this.convertToYouTube(url, sourcePlatform, true);
            }

            // Handle conversions FROM YouTube or YouTube Music
            if (sourcePlatform === 'youtube' || sourcePlatform === 'youtubeMusic') {
                return await this.convertFromYouTube(url, targetPlatform, sourcePlatform === 'youtubeMusic');
            }

            // Handle conversions TO SoundCloud
            if (targetPlatform === 'soundcloud') {
                return await this.convertToSoundCloud(url, sourcePlatform);
            }

            // Handle conversions FROM SoundCloud
            if (sourcePlatform === 'soundcloud') {
                return await this.convertFromSoundCloud(url, targetPlatform);
            }

            // Original Spotify <-> Apple Music conversions
            if (sourcePlatform === 'spotify' && targetPlatform === 'apple') {
                return await this.convertSpotifyToApple(url);
            } else if (sourcePlatform === 'apple' && targetPlatform === 'spotify') {
                return await this.convertAppleToSpotify(url);
            } else {
                throw new Error('Unsupported conversion direction');
            }

        } catch (error) {
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Detect platform from URL
    detectPlatform(url) {
        if (url.includes('spotify.com')) {
            return 'spotify';
        } else if (url.includes('music.apple.com')) {
            return 'apple';
        } else if (url.includes('music.youtube.com')) {
            return 'youtubeMusic';
        } else if (url.includes('youtube.com') || url.includes('youtu.be')) {
            return 'youtube';
        } else if (url.includes('music.amazon.com') || url.includes('amazon.com/music')) {
            return 'amazon';
        } else if (url.includes('tidal.com') || url.includes('listen.tidal.com')) {
            return 'tidal';
        } else if (url.includes('soundcloud.com')) {
            return 'soundcloud';
        }
        return null;
    }
}

export default MusicConverter;
