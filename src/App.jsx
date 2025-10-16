import { useState, useEffect } from 'react'

function App() {
  const [crate, setCrate] = useState([])
  const [inputUrl, setInputUrl] = useState('')
  const [hoveredId, setHoveredId] = useState(null)

  // Load crate from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem('musicCrate')
    if (saved) {
      setCrate(JSON.parse(saved))
    }
  }, [])

  // Save crate to localStorage whenever it changes
  useEffect(() => {
    localStorage.setItem('musicCrate', JSON.stringify(crate))
  }, [crate])

  // Extract platform and ID from music URL
  const parseUrl = (url) => {
    const platforms = {
      'spotify.com': 'Spotify',
      'music.apple.com': 'Apple Music',
      'youtube.com': 'YouTube',
      'youtu.be': 'YouTube',
      'soundcloud.com': 'SoundCloud',
      'tidal.com': 'Tidal',
      'music.amazon.com': 'Amazon Music'
    }

    for (const [domain, platform] of Object.entries(platforms)) {
      if (url.includes(domain)) {
        return {
          platform,
          url,
          id: Date.now() + Math.random(),
          addedAt: new Date().toLocaleDateString()
        }
      }
    }
    return null
  }

  const addToCrate = () => {
    if (!inputUrl.trim()) return

    const track = parseUrl(inputUrl)
    if (track) {
      setCrate([track, ...crate])
      setInputUrl('')
    } else {
      alert('Please enter a valid music link from Spotify, Apple Music, YouTube, SoundCloud, Tidal, or Amazon Music')
    }
  }

  const removeFromCrate = (id) => {
    setCrate(crate.filter(track => track.id !== id))
  }

  // Generate gradient based on platform
  const getPlatformGradient = (platform) => {
    const gradients = {
      'Spotify': 'from-green-500 to-green-700',
      'Apple Music': 'from-pink-500 to-red-600',
      'YouTube': 'from-red-500 to-red-700',
      'SoundCloud': 'from-orange-500 to-orange-700',
      'Tidal': 'from-blue-500 to-blue-700',
      'Amazon Music': 'from-blue-400 to-blue-600'
    }
    return gradients[platform] || 'from-gray-500 to-gray-700'
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-8">
      {/* Header */}
      <div className="max-w-7xl mx-auto mb-12">
        <h1 className="text-5xl font-bold mb-2 bg-gradient-to-r from-purple-400 to-pink-500 text-transparent bg-clip-text">
          Your Crate
        </h1>
        <p className="text-gray-400 text-lg">Save and organize your favorite music from any platform</p>
      </div>

      {/* Add Track Input */}
      <div className="max-w-7xl mx-auto mb-12">
        <div className="flex gap-4">
          <input
            type="text"
            value={inputUrl}
            onChange={(e) => setInputUrl(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && addToCrate()}
            placeholder="Paste a music link from Spotify, Apple Music, YouTube, etc."
            className="flex-1 px-6 py-4 bg-gray-800 border border-gray-700 rounded-lg focus:outline-none focus:border-purple-500 text-white placeholder-gray-500"
          />
          <button
            onClick={addToCrate}
            className="px-8 py-4 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg font-semibold hover:from-purple-600 hover:to-pink-600 transition-all"
          >
            Add to Crate
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="max-w-7xl mx-auto mb-8">
        <div className="flex gap-6">
          <div className="bg-gray-800 px-6 py-3 rounded-lg">
            <span className="text-gray-400">Total Tracks: </span>
            <span className="font-bold text-xl">{crate.length}</span>
          </div>
          <div className="bg-gray-800 px-6 py-3 rounded-lg">
            <span className="text-gray-400">Platforms: </span>
            <span className="font-bold text-xl">
              {new Set(crate.map(t => t.platform)).size}
            </span>
          </div>
        </div>
      </div>

      {/* Grid of Tracks */}
      {crate.length === 0 ? (
        <div className="max-w-7xl mx-auto text-center py-20">
          <div className="text-6xl mb-4">🎵</div>
          <p className="text-gray-500 text-xl">Your crate is empty. Add some tracks to get started!</p>
        </div>
      ) : (
        <div className="max-w-7xl mx-auto grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {crate.map((track) => (
            <div
              key={track.id}
              className="relative group"
              onMouseEnter={() => setHoveredId(track.id)}
              onMouseLeave={() => setHoveredId(null)}
            >
              {/* Card */}
              <div className={`bg-gradient-to-br ${getPlatformGradient(track.platform)} aspect-square rounded-lg p-6 flex flex-col justify-between transition-transform group-hover:scale-105`}>
                {/* Platform Badge */}
                <div className="flex justify-between items-start">
                  <span className="bg-black bg-opacity-40 px-3 py-1 rounded-full text-xs font-semibold">
                    {track.platform}
                  </span>
                  {hoveredId === track.id && (
                    <button
                      onClick={() => removeFromCrate(track.id)}
                      className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-full text-xs font-semibold transition-colors"
                    >
                      Remove
                    </button>
                  )}
                </div>

                {/* Track Icon */}
                <div className="text-center">
                  <div className="text-6xl mb-2">🎧</div>
                </div>

                {/* Date Added */}
                <div className="text-xs text-white text-opacity-70">
                  Added {track.addedAt}
                </div>
              </div>

              {/* Link on hover */}
              {hoveredId === track.id && (
                <div className="absolute bottom-0 left-0 right-0 bg-gray-800 rounded-b-lg p-3 text-xs">
                  <a
                    href={track.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-purple-400 hover:text-purple-300 truncate block"
                  >
                    {track.url}
                  </a>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default App
