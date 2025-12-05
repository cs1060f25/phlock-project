// Script to help get your Spotify refresh token
// Run: node get_refresh_token.js
// Then open the URL in your browser

const http = require('http');
const https = require('https');
const { URL } = require('url');

const clientId = '68032dd9c4774f2b8f16ced8c77c9d25';  // iOS app client ID
const clientSecret = 'b6e8c5db170740ff819baec4a6067cd7';  // Get from Spotify Dashboard
const redirectUri = 'http://127.0.0.1:8888/callback';  // Must use 127.0.0.1 not localhost
const scopes = 'user-read-email user-read-private';

const authUrl = 'https://accounts.spotify.com/authorize?' +
  'client_id=' + clientId +
  '&response_type=code' +
  '&redirect_uri=' + encodeURIComponent(redirectUri) +
  '&scope=' + encodeURIComponent(scopes);

console.log('\n📱 SPOTIFY REFRESH TOKEN HELPER\n');
console.log('Open this URL in your browser:\n');
console.log(authUrl);
console.log('\nWaiting for callback on http://localhost:8888...\n');

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost:8888');

  if (url.pathname === '/callback') {
    const code = url.searchParams.get('code');

    if (code) {
      console.log('Got authorization code, exchanging for tokens...');

      const data = 'grant_type=authorization_code&code=' + code + '&redirect_uri=' + encodeURIComponent(redirectUri);
      const credentials = Buffer.from(clientId + ':' + clientSecret).toString('base64');

      const tokenReq = https.request({
        hostname: 'accounts.spotify.com',
        port: 443,
        path: '/api/token',
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ' + credentials,
          'Content-Length': data.length
        }
      }, (tokenRes) => {
        let body = '';
        tokenRes.on('data', (chunk) => body += chunk);
        tokenRes.on('end', () => {
          const tokens = JSON.parse(body);

          console.log('\n✅ SUCCESS! Here are your tokens:\n');
          console.log('REFRESH TOKEN (save this to Supabase secrets):');
          console.log('─'.repeat(50));
          console.log(tokens.refresh_token);
          console.log('─'.repeat(50));
          console.log('\nRun this command to save it:');
          console.log('supabase secrets set SPOTIFY_USER_REFRESH_TOKEN="' + tokens.refresh_token + '" --project-ref szfxnzsapojuemltjghb');

          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end('<h1>Success!</h1><p>You can close this window. Check the terminal for your refresh token.</p>');

          server.close();
        });
      });

      tokenReq.write(data);
      tokenReq.end();
    } else {
      res.writeHead(400, { 'Content-Type': 'text/html' });
      res.end('<h1>Error</h1><p>No authorization code received.</p>');
    }
  }
});

server.listen(8888, () => {
  console.log('Server running...');
});
