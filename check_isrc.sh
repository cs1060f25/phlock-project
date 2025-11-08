#!/bin/bash
echo "=== Checking ISRC USUM70972068 ==="
curl -X POST "https://szfxnzsapojuemltjghb.supabase.co/functions/v1/validate-track" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc" \
  -H "Content-Type: application/json" \
  -d '{"trackId": "5nujrmhLynf4yMoMtj8AQF"}' 2>&1 | tail -1

echo ""
echo ""
echo "=== Checking wrong ID 3DamFFqW32WihKkTVlwTYQ ==="
curl -X POST "https://szfxnzsapojuemltjghb.supabase.co/functions/v1/validate-track" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc" \
  -H "Content-Type: application/json" \
  -d '{"trackId": "3DamFFqW32WihKkTVlwTYQ"}' 2>&1 | tail -1
