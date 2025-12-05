const https = require('https');

// First get token using client credentials
const clientId = 'ea7058353e994782aaee506b41c46857';  // From .env
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
  res.on('end', () => {
    console.log('Token Status:', res.statusCode);
    try {
      const parsed = JSON.parse(body);
      if (parsed.access_token) {
        console.log('Got access token, fetching playlist...');
        fetchPlaylist(parsed.access_token);
      } else {
        console.log('Token response:', body);
      }
    } catch (e) {
      console.log('Token error:', body);
    }
  });
});

tokenReq.on('error', (e) => console.error('Token Error:', e.message));
tokenReq.write(tokenData);
tokenReq.end();

function fetchPlaylist(token) {
  const playlistId = '37i9dQZF1DX2L0iB23Enbq';
  
  // First try to get playlist info
  const options = {
    hostname: 'api.spotify.com',
    port: 443,
    path: `/v1/playlists/${playlistId}`,
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  };

  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => body += chunk);
    res.on('end', () => {
      console.log('Playlist Status:', res.statusCode);
      try {
        const parsed = JSON.parse(body);
        if (parsed.name) {
          console.log('Playlist name:', parsed.name);
          console.log('Tracks count:', parsed.tracks?.total);
        } else {
          console.log('Playlist response:', body.substring(0, 500));
        }
      } catch (e) {
        console.log('Parse error:', body.substring(0, 500));
      }
    });
  });

  req.on('error', (e) => console.error('Playlist Error:', e.message));
  req.end();
}
