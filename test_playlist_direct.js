const https = require('https');

// Same credentials as get_refresh_token.js
const clientId = '68032dd9c4774f2b8f16ced8c77c9d25';
const clientSecret = 'b6e8c5db170740ff819baec4a6067cd7';

// First get a fresh access token using the refresh token
// We'll read from the environment or prompt
const refreshToken = process.argv[2];

if (!refreshToken) {
  console.log('Usage: node test_playlist_direct.js <REFRESH_TOKEN>');
  console.log('\nGet your refresh token by running: node get_refresh_token.js');
  process.exit(1);
}

const tokenData = `grant_type=refresh_token&refresh_token=${refreshToken}`;
const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

console.log('Getting access token...\n');

const tokenReq = https.request({
  hostname: 'accounts.spotify.com',
  port: 443,
  path: '/api/token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': `Basic ${credentials}`,
    'Content-Length': tokenData.length
  }
}, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    if (res.statusCode !== 200) {
      console.log('Token error:', res.statusCode, body);
      return;
    }
    
    const { access_token } = JSON.parse(body);
    console.log('Got access token!\n');
    
    // Test each playlist
    const playlists = {
      'viral-hits': '37i9dQZF1DX2L0iB23Enbq',
      'new-music-friday': '37i9dQZF1DX4JAvHpjipBk',
      'todays-top-hits': '37i9dQZF1DXcBWIGoYBM5M'
    };
    
    Object.entries(playlists).forEach(([name, id]) => {
      https.request({
        hostname: 'api.spotify.com',
        port: 443,
        path: `/v1/playlists/${id}/tracks?limit=3&fields=items(track(name,artists(name)))`,
        method: 'GET',
        headers: { 'Authorization': `Bearer ${access_token}` }
      }, (res2) => {
        let body2 = '';
        res2.on('data', (chunk) => body2 += chunk);
        res2.on('end', () => {
          console.log(`${name} (${id}): ${res2.statusCode}`);
          if (res2.statusCode === 200) {
            const data = JSON.parse(body2);
            data.items?.slice(0, 2).forEach((item, i) => {
              if (item.track) {
                console.log(`  ${i+1}. ${item.track.name} - ${item.track.artists?.[0]?.name}`);
              }
            });
          } else {
            console.log('  Error:', body2.substring(0, 200));
          }
          console.log('');
        });
      }).end();
    });
  });
});

tokenReq.on('error', (e) => console.error('Request error:', e));
tokenReq.write(tokenData);
tokenReq.end();
