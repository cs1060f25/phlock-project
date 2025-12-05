// Fetch your Spotify refresh token from the platform_tokens table
// Run: node get_token_from_db.js

const https = require('https');

const SUPABASE_URL = 'szfxnzsapojuemltjghb.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc';

// Query platform_tokens for Spotify tokens
const query = encodeURIComponent('platform=eq.spotify&select=refresh_token,user_id&limit=5');

const options = {
  hostname: SUPABASE_URL,
  port: 443,
  path: '/rest/v1/platform_tokens?' + query,
  method: 'GET',
  headers: {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
    'Content-Type': 'application/json'
  }
};

console.log('\nFetching Spotify refresh tokens from database...\n');

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    if (res.statusCode === 200) {
      const tokens = JSON.parse(body);
      if (tokens.length === 0) {
        console.log('No Spotify tokens found in database.');
        console.log('Make sure you\'ve logged in with Spotify in the iOS app first.');
      } else {
        console.log('Found ' + tokens.length + ' Spotify token(s):\n');
        tokens.forEach((t, i) => {
          console.log('Token ' + (i + 1) + ':');
          console.log('  User ID: ' + t.user_id);
          console.log('  Refresh Token: ' + t.refresh_token);
          console.log('');
        });

        // Print the command to set the secret
        const token = tokens[0].refresh_token;
        console.log('─'.repeat(60));
        console.log('\nTo set this as a Supabase secret, run:\n');
        console.log('supabase secrets set SPOTIFY_USER_REFRESH_TOKEN="' + token + '" --project-ref szfxnzsapojuemltjghb');
        console.log('\nThen deploy the edge function:\n');
        console.log('supabase functions deploy get-playlist-tracks --project-ref szfxnzsapojuemltjghb');
      }
    } else {
      console.log('Error: ' + res.statusCode);
      console.log(body);
    }
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.end();
