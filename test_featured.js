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
    
    // Try featured playlists endpoint
    https.request({
      hostname: 'api.spotify.com', port: 443, path: '/v1/browse/featured-playlists?country=US&limit=10', method: 'GET',
      headers: { 'Authorization': `Bearer ${access_token}` }
    }, (res2) => {
      let body2 = ''; res2.on('data', (c) => body2 += c);
      res2.on('end', () => {
        console.log('Featured playlists status:', res2.statusCode);
        if (res2.statusCode === 200) {
          const data = JSON.parse(body2);
          console.log('Message:', data.message);
          console.log('Playlists:');
          data.playlists?.items?.forEach((p, i) => {
            console.log(`  ${i+1}. ${p.name} (${p.id}) - ${p.tracks?.total} tracks`);
          });
        } else {
          console.log('Response:', body2.substring(0, 500));
        }
      });
    }).end();
    
    // Also try browse categories
    https.request({
      hostname: 'api.spotify.com', port: 443, path: '/v1/browse/categories?country=US&limit=10', method: 'GET',
      headers: { 'Authorization': `Bearer ${access_token}` }
    }, (res3) => {
      let body3 = ''; res3.on('data', (c) => body3 += c);
      res3.on('end', () => {
        console.log('\nCategories status:', res3.statusCode);
        if (res3.statusCode === 200) {
          const data = JSON.parse(body3);
          console.log('Categories:');
          data.categories?.items?.slice(0, 5).forEach((c, i) => {
            console.log(`  ${i+1}. ${c.name} (${c.id})`);
          });
        }
      });
    }).end();
  });
}).write(tokenData);
