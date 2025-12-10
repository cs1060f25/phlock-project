# Phlock Test Suite

## Quick Start

```bash
npm install
npm test
```

No additional configuration or credentials required.

---

## What's Being Tested

### Unit Tests (17 tests)

Test individual functions extracted from the Supabase Edge Functions. No network calls.

| Test Group | What It Tests |
|------------|---------------|
| **Search Request Validation** | Validates user search input before sending to Spotify API. Tests empty queries, type checking, whitespace handling, and limit bounds (1-50). |
| **Track Request Validation** | Validates track selection requests. Ensures either a Spotify track ID, ISRC code, or track name + artist name is provided. |
| **Artist Parsing** | Parses artist strings with featured artists (e.g., "Dua Lipa ft. DaBaby" → ["dua lipa", "dababy"]). Handles "ft.", "feat.", "&", commas. |
| **Artist Matching** | Matches track artists against expected names. Verifies correct song version when multiple exist. |
| **Track Transformation** | Transforms Spotify API responses into iOS app format (id, name, artistName, albumArtUrl, previewUrl, spotifyUrl). |
| **End-to-End Workflow (Unit)** | Validates complete flow from search → selection → validation → transformation using mock data. |

### Integration Tests (2 tests)

Real HTTP calls to deployed Supabase Edge Functions. These are **read-only** — they query Spotify's API but don't modify any database.

| Test | Endpoint | What It Verifies |
|------|----------|------------------|
| **Search API** | `search-spotify-tracks` | Searches for "Bohemian Rhapsody Queen", verifies response contains tracks with id, name, artists. |
| **Validate API** | `validate-track` | Looks up "Blinding Lights" by The Weeknd, verifies complete metadata (id, name, artistName, albumArtUrl, spotifyUrl). |

---

## Expected Output

```
 PASS  tests/api.test.js
  Search Request Validation
    ✓ rejects empty query
    ✓ rejects null query
    ✓ rejects numeric query
    ✓ accepts valid query string
    ✓ trims whitespace from query
    ✓ clamps limit to maximum of 50
    ✓ clamps limit to minimum of 1
  Track Request Validation
    ✓ rejects empty request
    ✓ accepts trackId alone
    ✓ accepts isrc alone
    ✓ accepts trackName with artistName
    ✓ rejects trackName without artistName
  Artist Parsing
    ✓ handles single artist
    ✓ handles ft. format
    ✓ handles feat. format
    ✓ handles & format
    ✓ handles comma format
  Artist Matching
    ✓ matches single artist
    ✓ matches featured artists
    ✓ rejects wrong artist
    ✓ case insensitive matching
  Track Transformation
    ✓ transforms track with all fields
    ✓ uses fallback preview URL when provided
  End-to-End Workflow (Unit)
    ✓ complete search-to-share flow validates correctly
  Integration Tests - Live API
    ✓ search-spotify-tracks returns results for valid query
    ✓ validate-track returns complete track data

Test Suites: 1 passed, 1 total
Tests:       19 passed, 19 total
```

---

## Troubleshooting

- **Network errors**: Integration tests require internet access
- **Timeouts**: Integration tests have 15-second timeout; re-run if Spotify API is slow
- **`jest: command not found`**: Run `npm install` first
