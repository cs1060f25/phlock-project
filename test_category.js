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
    
    // Try category playlists - using "toplists" or "pop" category
    const categories = ['toplists', 'pop', '0JQ5DAqbMKFC7do0jUgBzi', '0JQ5DAqbMKFGaKcChsSgUO'];
    
    categories.forEach(cat => {
      https.request({
        hostname: 'api.spotify.com', port: 443, 
        path: `/v1/browse/categories/${cat}/playlists?country=US&limit=5`, 
        method: 'GET',
        headers: { 'Authorization': `Bearer ${access_token}` }
      }, (res2) => {
        let body2 = ''; res2.on('data', (c) => body2 += c);
        res2.on('end', () => {
          console.log(`\nCategory "${cat}" status:`, res2.statusCode);
          if (res2.statusCode === 200) {
            const data = JSON.parse(body2);
            data.playlists?.items?.slice(0, 3).forEach((p, i) => {
              console.log(`  ${i+1}. ${p.name} (${p.id})`);
            });
          } else {
            console.log('  Error:', body2.substring(0, 200));
          }
        });
      }).end();
    });
    
    // Also try new releases albums endpoint
    https.request({
      hostname: 'api.spotify.com', port: 443, 
      path: '/v1/browse/new-releases?country=US&limit=5', 
      method: 'GET',
      headers: { 'Authorization': `Bearer ${access_token}` }
    }, (res3) => {
      let body3 = ''; res3.on('data', (c) => body3 += c);
      res3.on('end', () => {
        console.log('\nNew releases status:', res3.statusCode);
        if (res3.statusCode === 200) {
          const data = JSON.parse(body3);
          data.albums?.items?.slice(0, 3).forEach((a, i) => {
            console.log(`  ${i+1}. ${a.name} by ${a.artists?.[0]?.name}`);
          });
        }
      });
    }).end();
  });
}).write(tokenData);
