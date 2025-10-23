// Utility functions for URL parsing and validation

export function extractSpotifyTrackId(url) {
    try {
        const match = url.match(/\/track\/([a-zA-Z0-9]+)/);
        return match ? match[1] : null;
    } catch (error) {
        return null;
    }
}

export function extractAppleMusicTrackId(url) {
    try {
        const match = url.match(/i=(\d+)/);
        return match ? match[1] : null;
    } catch (error) {
        return null;
    }
}

export function isValidSpotifyUrl(url) {
    try {
        const urlObj = new URL(url);
        return urlObj.hostname.includes('spotify.com') && extractSpotifyTrackId(url);
    } catch (error) {
        return false;
    }
}

export function isValidAppleMusicUrl(url) {
    try {
        const urlObj = new URL(url);
        return urlObj.hostname.includes('music.apple.com') && extractAppleMusicTrackId(url);
    } catch (error) {
        return false;
    }
}

export function detectPlatform(url) {
    if (isValidSpotifyUrl(url)) return 'spotify';
    if (isValidAppleMusicUrl(url)) return 'apple';
    return null;
}

export function isValidUrl(string) {
    try {
        new URL(string);
        return true;
    } catch (_) {
        return false;
    }
}
