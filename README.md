# Prototype 2: Minimal List View

## Design Approach
Brutalist, minimal design inspired by Craigslist and early web aesthetics. Proves you don't need modern frameworks.

## Tech Stack
- Vanilla HTML
- Vanilla CSS (inline in HTML)
- Vanilla JavaScript (no frameworks, no build process)
- localStorage for persistence

## Key Features
- Simple table-based layout
- No dependencies, no build process
- Black and white color scheme
- Monospace font throughout
- Direct, functional interface

## Design Decisions
- **No frameworks**: Demonstrates simplicity and speed
- **Table layout**: Brutalist approach, very functional
- **Monospace fonts**: Technical, terminal-like feel
- **Black borders everywhere**: Stark, no-nonsense aesthetic
- **Single HTML file**: Everything in one place, easy to deploy

## Why This Might Be Better
- Lightning fast - no React overhead
- Works without JavaScript build tools
- Tiny file size
- No dependencies to maintain
- Accessible by default

## To Run Locally
Simply open `index.html` in a browser, or:
```bash
python3 -m http.server 8000
```

## To Deploy to Vercel
```bash
vercel --prod
```
