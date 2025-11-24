#!/bin/bash

# Test if Spotify preview URLs are working
echo "Testing Spotify preview URLs..."

# Mr. Brightside - The Killers (should work)
echo -n "1. Mr. Brightside: "
curl -s -o /dev/null -w "%{http_code}" "https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba"
echo ""

# Cruel Summer - Taylor Swift (should work)
echo -n "2. Cruel Summer: "
curl -s -o /dev/null -w "%{http_code}" "https://p.scdn.co/mp3-preview/5ac5b897fef98784b7bba8576c160024a327195e"
echo ""

# Vampire - Olivia Rodrigo (should work)
echo -n "3. Vampire: "
curl -s -o /dev/null -w "%{http_code}" "https://p.scdn.co/mp3-preview/53cc3c883c978d2c46ac0f3e63f2e35c87d96b69"
echo ""

# Old Blinding Lights URL (might not work)
echo -n "4. Blinding Lights (old): "
curl -s -o /dev/null -w "%{http_code}" "https://p.scdn.co/mp3-preview/e9f1e0e7e3c6c1277f29c1df52c5af5b6e26a55c"
echo ""

# Old Peaches URL (might not work)
echo -n "5. Peaches (old): "
curl -s -o /dev/null -w "%{http_code}" "https://p.scdn.co/mp3-preview/8cc84b3df71da3f32f1b66ca83cd985e14f9c759"
echo ""

echo ""
echo "Status codes:"
echo "200 = Working"
echo "403 = Forbidden/Expired"
echo "404 = Not Found"