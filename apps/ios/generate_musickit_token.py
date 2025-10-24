#!/usr/bin/env python3
"""
Generate Apple Music MusicKit Developer Token (JWT)
This token is valid for 6 months and is used to authenticate your app with Apple Music API.
"""

import jwt
import datetime
import os

# Apple Developer credentials
TEAM_ID = "Y23RJZMV5M"
KEY_ID = "R4WYDP8D72"
PRIVATE_KEY_PATH = os.path.expanduser("~/.apple-keys/AuthKey_R4WYDP8D72.p8")

# Read the private key
try:
    with open(PRIVATE_KEY_PATH, 'r') as f:
        private_key = f.read()
except FileNotFoundError:
    print(f"❌ Error: Could not find private key at {PRIVATE_KEY_PATH}")
    print("Make sure the .p8 file is in the correct location.")
    exit(1)

# Create the JWT token
headers = {
    "alg": "ES256",
    "kid": KEY_ID
}

# Token valid for 6 months (maximum allowed by Apple)
now = datetime.datetime.utcnow()
expiration = now + datetime.timedelta(days=180)

payload = {
    "iss": TEAM_ID,
    "iat": int(now.timestamp()),
    "exp": int(expiration.timestamp())
}

# Generate the token
try:
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)

    print("✅ Apple Music Developer Token Generated Successfully!")
    print("\n" + "="*80)
    print("TOKEN (copy this to Config.swift):")
    print("="*80)
    print(token)
    print("="*80)
    print(f"\n📅 Valid until: {expiration.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print("\n💡 Copy the token above and paste it into:")
    print("   apps/ios/phlock/phlock/Services/Config.swift")
    print("   Replace: static let appleMusicDeveloperToken = \"your-apple-music-developer-token\"")

except Exception as e:
    print(f"❌ Error generating token: {e}")
    print("\n💡 Make sure you have PyJWT and cryptography installed:")
    print("   pip install pyjwt cryptography")
    exit(1)
