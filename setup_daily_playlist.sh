#!/bin/bash

echo "🎵 Setting up Daily Playlist feature..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first."
    exit 1
fi

echo -e "${YELLOW}Step 1: Adding phlock columns to database...${NC}"
# Run migration to add columns
supabase db push --include-migrations 20251122000001_add_phlock_columns.sql 2>/dev/null || true

echo -e "${YELLOW}Step 2: Running seed data for testing...${NC}"
# Execute seed data directly using supabase db execute
supabase db execute --file supabase/seed/007_daily_playlist_dummy_data.sql

echo -e "${GREEN}✅ Daily Playlist setup complete!${NC}"
echo ""
echo "You should now see:"
echo "  • 5 phlock members in position 1-5"
echo "  • Daily songs from each member for today"
echo "  • Full daily playlist in the Feed tab"
echo ""
echo "Test credentials:"
echo "  Auth User ID: 45db2427-9b99-49bf-a334-895ec91b038c"