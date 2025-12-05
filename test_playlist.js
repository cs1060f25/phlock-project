const https = require('https');

const playlistArg = process.argv[2] || 'viral-hits';
const data = JSON.stringify({ playlist: playlistArg, limit: 5 });

const options = {
  hostname: 'szfxnzsapojuemltjghb.supabase.co',
  port: 443,
  path: '/functions/v1/get-playlist-tracks',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc',
    'Content-Length': data.length
  }
};

console.log('Testing get-playlist-tracks edge function...\n');

const req = https.request(options, (res) => {
  console.log('Status:', res.statusCode);
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(body);
      if (json.error) {
        console.log('Error:', json.error);
      } else if (json.tracks) {
        console.log('Success! Got', json.tracks.length, 'tracks:\n');
        json.tracks.forEach((t, i) => {
          console.log('  ' + (i + 1) + '. ' + t.name + ' - ' + t.artistName);
        });
      } else {
        console.log('Response:', JSON.stringify(json, null, 2));
      }
    } catch (e) {
      console.log('Raw response:', body);
    }
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
});

req.write(data);
req.end();
