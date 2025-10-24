// Simple test file to verify URL parsing functionality
import { extractSpotifyTrackId, extractAppleMusicTrackId } from './src/utils.js';

console.log('🧪 Testing Music Link Converter...\n');

// Test Spotify URL parsing
const spotifyUrl = 'https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh?si=abc123';
const spotifyId = extractSpotifyTrackId(spotifyUrl);
console.log('Spotify URL:', spotifyUrl);
console.log('Extracted ID:', spotifyId);
console.log('✅ Spotify parsing:', spotifyId === '4iV5W9uYEdYUVa79Axb7Rh' ? 'PASS' : 'FAIL');

console.log('\n---\n');

// Test Apple Music URL parsing
const appleUrl = 'https://music.apple.com/us/album/anti-hero/1646849437?i=1646849440';
const appleId = extractAppleMusicTrackId(appleUrl);
console.log('Apple Music URL:', appleUrl);
console.log('Extracted ID:', appleId);
console.log('✅ Apple Music parsing:', appleId === '1646849440' ? 'PASS' : 'FAIL');

console.log('\n🎉 Tests completed!');
