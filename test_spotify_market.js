const https = require('https');

const clientId = 'ea7058353e994782aaee506b41c46857';
const clientSecret = '550b93d8e9c1453f88f9e0f702e176a6';

const tokenData = 'grant_type=client_credentials';
const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

const tokenOptions = {
  hostname: 'accounts.spotify.com',
  port: 443,
  path: '/api/token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': `Basic ${credentials}`,
    'Content-Length': tokenData.length
  }
};

const tokenReq = https.request(tokenOptions, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', async () => {
    const parsed = JSON.parse(body);
    if (parsed.access_token) {
      const token = parsed.access_token;
      
      // Try different playlists
      const playlists = [
        { name: 'Viral Hits', id: '37i9dQZF1DX2L0iB23Enbq' },
        { name: 'Today\'s Top Hits', id: '37i9dQZF1DXcBWIGoYBM5M' },
        { name: 'New Music Friday', id: '37i9dQZF1DX4JAvHpjipBk' },
        { name: 'Top 50 Global', id: '37i9dQZEVXbMDoHDwVN2tF' },
        { name: 'Viral 50 Global', id: '37i9dQZEVXbLiRSasKsNU9' },
      ];
      
      for (const pl of playlists) {
        await testPlaylist(token, pl.name, pl.id);
      }
    }
  });
});

tokenReq.write(tokenData);
tokenReq.end();

function testPlaylist(token, name, playlistId) {
  return new Promise((resolve) => {
    const options = {
      hostname: 'api.spotify.com',
      port: 443,
      path: `/v1/playlists/${playlistId}?market=US`,
      method: 'GET',
      headers: { 'Authorization': `Bearer ${token}` }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        console.log(`${name} (${playlistId}): ${res.statusCode}`);
        if (res.statusCode === 200) {
          const parsed = JSON.parse(body);
          console.log(`  -> Found! Tracks: ${parsed.tracks?.total}`);
        }
        resolve();
      });
    });
    req.end();
  });
}
