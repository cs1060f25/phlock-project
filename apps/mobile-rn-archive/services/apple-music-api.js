// Apple Music API Service
import { CONFIG } from './config';
import jsrsasign from 'jsrsasign';
import { encode as base64Encode } from 'base-64';

class AppleMusicAPI {
    constructor() {
        this.baseURL = 'https://api.music.apple.com/v1';
        this.teamId = CONFIG.APPLE_MUSIC_TEAM_ID;
        this.keyId = CONFIG.APPLE_MUSIC_KEY_ID;
        // Ensure the private key has proper newlines
        this.privateKey = CONFIG.APPLE_MUSIC_PRIVATE_KEY.trim();
        this.storefront = 'us'; // Default to US storefront
        this.developerToken = null;
    }

    getDeveloperToken() {
        if (this.developerToken) {
            return this.developerToken;
        }

        try {
            console.log('[Apple Music] Generating developer token...');
            console.log('[Apple Music] Team ID:', this.teamId);
            console.log('[Apple Music] Key ID:', this.keyId);

            // Create JWT header
            const header = JSON.stringify({
                alg: 'ES256',
                kid: this.keyId,
                typ: 'JWT'
            });

            // Create JWT payload
            const now = Math.floor(Date.now() / 1000);
            const payload = JSON.stringify({
                iss: this.teamId,
                iat: now,
                exp: now + (180 * 24 * 60 * 60) // 180 days
            });

            // Base64URL encode header and payload
            const base64UrlEncode = (str) => {
                return base64Encode(str)
                    .replace(/\+/g, '-')
                    .replace(/\//g, '_')
                    .replace(/=/g, '');
            };

            const encodedHeader = base64UrlEncode(header);
            const encodedPayload = base64UrlEncode(payload);
            const signatureInput = `${encodedHeader}.${encodedPayload}`;

            console.log('[Apple Music] JWT Header:', encodedHeader);
            console.log('[Apple Music] JWT Payload:', encodedPayload);

            // Sign using ECDSA with SHA256
            const sig = new jsrsasign.KJUR.crypto.Signature({ alg: 'SHA256withECDSA' });
            const prvKey = jsrsasign.KEYUTIL.getKey(this.privateKey);
            sig.init(prvKey);
            sig.updateString(signatureInput);
            const sigHex = sig.sign();

            console.log('[Apple Music] Signature hex length:', sigHex.length);

            // Convert DER-encoded signature to raw R+S format (required for JWT)
            // ECDSA P-256 signatures should be 64 bytes (32 bytes R + 32 bytes S)
            const sigValueHex = jsrsasign.KJUR.crypto.ECDSA.parseSigHexInHexRS(sigHex);
            const rHex = sigValueHex.r;
            const sHex = sigValueHex.s;

            console.log('[Apple Music] R hex:', rHex);
            console.log('[Apple Music] S hex:', sHex);

            // Combine R and S into raw format
            const rBytes = jsrsasign.hextoArrayBuffer(rHex);
            const sBytes = jsrsasign.hextoArrayBuffer(sHex);
            const rawSig = new Uint8Array(64);
            const rArray = new Uint8Array(rBytes);
            const sArray = new Uint8Array(sBytes);

            console.log('[Apple Music] R array length:', rArray.length);
            console.log('[Apple Music] S array length:', sArray.length);

            // Pad or trim R and S to exactly 32 bytes each
            // If longer than 32, take the last 32 bytes (removes leading zeros)
            // If shorter than 32, pad with leading zeros
            if (rArray.length >= 32) {
                rawSig.set(rArray.slice(-32), 0);
            } else {
                rawSig.set(rArray, 32 - rArray.length);
            }

            if (sArray.length >= 32) {
                rawSig.set(sArray.slice(-32), 32);
            } else {
                rawSig.set(sArray, 64 - sArray.length);
            }

            // Convert to base64url
            const sigString = String.fromCharCode.apply(null, rawSig);
            const sigB64 = base64Encode(sigString);
            const encodedSignature = sigB64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

            const token = `${signatureInput}.${encodedSignature}`;

            console.log('[Apple Music] Generated token (first 50 chars):', token.substring(0, 50) + '...');

            this.developerToken = token;
            return token;
        } catch (error) {
            console.error('Apple Music token generation error:', error);
            throw new Error(`Failed to generate Apple Music token: ${error.message}`);
        }
    }

    async getTrack(trackId) {
        try {
            const token = await this.getDeveloperToken();
            const response = await fetch(`${this.baseURL}/catalog/${this.storefront}/songs/${trackId}`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (!response.ok) {
                throw new Error(`Apple Music API error: ${response.status}`);
            }

            const data = await response.json();
            return data.data[0]; // Apple Music returns array in data property
        } catch (error) {
            console.error('Error fetching Apple Music track:', error);
            throw error;
        }
    }

    async searchSongs(query, limit = 10) {
        try {
            const token = await this.getDeveloperToken();
            const url = `${this.baseURL}/catalog/${this.storefront}/search?term=${encodeURIComponent(query)}&types=songs&limit=${limit}`;
            console.log('[Apple Music] Search URL:', url);
            console.log('[Apple Music] Search query:', query);

            const response = await fetch(url, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            console.log('[Apple Music] Response status:', response.status);

            if (!response.ok) {
                const errorText = await response.text();
                console.error('[Apple Music] Error response:', errorText);
                throw new Error(`Apple Music search error: ${response.status} - ${errorText}`);
            }

            const data = await response.json();
            console.log('[Apple Music] Search results:', data.results?.songs?.data?.length || 0, 'songs found');
            return data.results.songs?.data || [];
        } catch (error) {
            console.error('Error searching Apple Music:', error);
            throw error;
        }
    }

    // Extract track ID from Apple Music URL
    static extractTrackId(url) {
        try {
            console.log('Extracting track ID from URL:', url);
            // Handle multiple Apple Music URL formats:
            // 1. /album/...?i=123 (album page with track)
            // 2. /song/123 (direct song ID)
            // 3. /song/song-title/123 (song with title in path)
            const albumMatch = url.match(/i=(\d+)/);
            // Handle multiple Apple Music URL formats:
            // 1. /song/123 (direct song ID)
            // 2. /song/song-title/123 (song with title in path)
            const songMatch = url.match(/\/song\/(?:[^\/]*\/)?(\d+)(?:\?|$)/);
            
            console.log('Album match:', albumMatch);
            console.log('Song match:', songMatch);
            
            const trackId = albumMatch ? albumMatch[1] : (songMatch ? songMatch[1] : null);
            console.log('Extracted track ID:', trackId);
            
            return trackId;
        } catch (error) {
            console.error('Error extracting track ID:', error);
            return null;
        }
    }

    // Generate Apple Music URL from track ID
    static generateUrl(trackId, storefront = 'us') {
        // Note: We need album ID for Apple Music URLs, track ID alone isn't sufficient
        // This is a simplified version - in practice, you'd need album context
        return `https://music.apple.com/${storefront}/song/${trackId}`;
    }

    // More accurate URL generation with album context
    static generateUrlWithAlbum(trackId, albumId, storefront = 'us') {
        if (!trackId) {
            throw new Error('Track ID is required for Apple Music URL generation');
        }
        
        if (!albumId) {
            console.warn('No album ID found, using fallback URL format');
            return `https://music.apple.com/${storefront}/song/${trackId}`;
        }
        
        return `https://music.apple.com/${storefront}/album/${albumId}?i=${trackId}`;
    }
}

export default AppleMusicAPI;
