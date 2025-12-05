const https = require('https');

const clientId = 'ea7058353e994782aaee506b41c46857';
const clientSecret = '550b93d8e9c1453f88f9e0f702e176a6';

const tokenData = 'grant_type=client_credentials';
const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

https.request({
  hostname: 'accounts.spotify.com', port: 443, path: '/api/token', method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': `Basic ${credentials}`, 'Content-Length': tokenData.length }
}, (res) => {
  let body = ''; res.on('data', (c) => body += c);
  res.on('end', () => {
    const { access_token } = JSON.parse(body);
    
    // Try searching for a track instead to confirm the token works
    https.request({
      hostname: 'api.spotify.com', port: 443, path: '/v1/search?q=beatles&type=track&limit=1', method: 'GET',
      headers: { 'Authorization': `Bearer ${access_token}` }
    }, (res2) => {
      let body2 = ''; res2.on('data', (c) => body2 += c);
      res2.on('end', () => {
        console.log('Search status:', res2.statusCode);
        const data = JSON.parse(body2);
        if (data.tracks?.items?.length > 0) {
          console.log('Search works! Found:', data.tracks.items[0].name);
        } else {
          console.log('Search result:', body2.substring(0, 300));
        }
      });
    }).end();
    
    // Try getting user-created public playlist (not Spotify editorial)
    https.request({
      hostname: 'api.spotify.com', port: 443, path: '/v1/playlists/3cEYpjA9oz9GiPac4AsH4n', method: 'GET',
      headers: { 'Authorization': `Bearer ${access_token}` }
    }, (res3) => {
      let body3 = ''; res3.on('data', (c) => body3 += c);
      res3.on('end', () => {
        console.log('Public playlist status:', res3.statusCode);
        if (res3.statusCode === 200) {
          const data = JSON.parse(body3);
          console.log('Playlist name:', data.name);
        }
      });
    }).end();
  });
}).write(tokenData);
