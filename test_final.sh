#!/bin/bash
echo "=== Testing: Levitating by Dua Lipa ft. DaBaby ==="
echo "Expected ID: 5nujrmhLynf4yMoMtj8AQF"
echo "Expected name: Levitating (feat. DaBaby)"
echo ""

curl -X POST "https://szfxnzsapojuemltjghb.supabase.co/functions/v1/validate-track" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc" \
  -H "Content-Type: application/json" \
  -d '{"trackName": "Levitating", "artistName": "Dua Lipa ft. DaBaby"}' 2>&1 | grep -E "\"id\"|\"name\"|\"popularity\"" | head -4

echo ""
echo "=== Testing with wrong ID (should correct to 5nujrmhLynf4yMoMtj8AQF) ==="
curl -X POST "https://szfxnzsapojuemltjghb.supabase.co/functions/v1/validate-track" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc" \
  -H "Content-Type: application/json" \
  -d '{"trackId": "3DamFFqW32WihKkTVlwTYQ", "trackName": "Levitating", "artistName": "Dua Lipa ft. DaBaby"}' 2>&1 | grep -E "\"id\"|\"name\"|\"popularity\"" | head -4
