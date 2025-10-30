#!/usr/bin/env node

/**
 * Generate Apple Sign In Client Secret (JWT Token)
 *
 * This script generates the JWT token needed for Apple OAuth in Supabase.
 *
 * Usage:
 *   node generate_apple_client_secret.js
 *
 * You'll need to install jsonwebtoken:
 *   npm install jsonwebtoken
 */

const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

// REPLACE THESE WITH YOUR VALUES
const TEAM_ID = 'Y23RJZMV5M';
const SERVICES_ID = 'com.phlock.signin'; // Your Services ID
const KEY_ID = '9HJKCR6B85'; // Replace with your Key ID from Apple
const PRIVATE_KEY_PATH = './AuthKey_9HJKCR6B85.p8'; // Path to your .p8 file

// JWT token expires in 6 months (Apple's maximum)
const TOKEN_EXPIRY_SECONDS = 15777000; // 6 months in seconds

function generateClientSecret() {
  try {
    // Read the private key file
    const privateKey = fs.readFileSync(path.resolve(PRIVATE_KEY_PATH), 'utf8');

    // Current timestamp
    const now = Math.floor(Date.now() / 1000);

    // Create the JWT payload
    const payload = {
      iss: TEAM_ID,
      iat: now,
      exp: now + TOKEN_EXPIRY_SECONDS,
      aud: 'https://appleid.apple.com',
      sub: SERVICES_ID
    };

    // Sign the JWT with ES256 algorithm
    const clientSecret = jwt.sign(payload, privateKey, {
      algorithm: 'ES256',
      header: {
        alg: 'ES256',
        kid: KEY_ID,
        typ: 'JWT'
      }
    });

    console.log('\n✅ Apple Client Secret (JWT Token) generated successfully!\n');
    console.log('Copy this token and paste it into Supabase Dashboard > Apple Provider > Secret Key:\n');
    console.log('─'.repeat(80));
    console.log(clientSecret);
    console.log('─'.repeat(80));
    console.log('\n⚠️  This token expires in 6 months. Generate a new one before expiry.\n');

    // Also save to file
    fs.writeFileSync('apple_client_secret.txt', clientSecret);
    console.log('💾 Token also saved to: apple_client_secret.txt\n');

    return clientSecret;
  } catch (error) {
    console.error('❌ Error generating client secret:', error.message);
    console.error('\nMake sure:');
    console.error('1. You have installed jsonwebtoken: npm install jsonwebtoken');
    console.error('2. Your .p8 file path is correct');
    console.error('3. Your Team ID, Services ID, and Key ID are correct');
    process.exit(1);
  }
}

// Run the generator
generateClientSecret();
