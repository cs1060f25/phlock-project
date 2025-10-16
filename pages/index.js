import { useState, useEffect } from 'react'
import Head from 'next/head'

export default function Home() {
  const [crate, setCrate] = useState([])
  const [inputUrl, setInputUrl] = useState('')
  const [username, setUsername] = useState('')
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    // Check for saved username
    const saved = localStorage.getItem('crateUsername')
    if (saved) {
      setUsername(saved)
      setIsLoggedIn(true)
      fetchCrate(saved)
    }
  }, [])

  const fetchCrate = async (user) => {
    try {
      setLoading(true)
      const res = await fetch(`/api/tracks?user=${user}`)
      const data = await res.json()
      setCrate(data.tracks || [])
    } catch (error) {
      console.error('Error fetching crate:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleLogin = () => {
    if (username.trim()) {
      localStorage.setItem('crateUsername', username)
      setIsLoggedIn(true)
      fetchCrate(username)
    }
  }

  const handleLogout = () => {
    localStorage.removeItem('crateUsername')
    setIsLoggedIn(false)
    setUsername('')
    setCrate([])
  }

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
        return { platform, url }
      }
    }
    return null
  }

  const addToCrate = async () => {
    if (!inputUrl.trim()) return

    const trackData = parseUrl(inputUrl)
    if (!trackData) {
      alert('Invalid music link')
      return
    }

    try {
      const res = await fetch('/api/tracks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user: username,
          ...trackData
        })
      })

      if (res.ok) {
        fetchCrate(username)
        setInputUrl('')
      }
    } catch (error) {
      console.error('Error adding track:', error)
    }
  }

  const removeTrack = async (id) => {
    try {
      const res = await fetch('/api/tracks', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user: username, id })
      })

      if (res.ok) {
        fetchCrate(username)
      }
    } catch (error) {
      console.error('Error removing track:', error)
    }
  }

  if (!isLoggedIn) {
    return (
      <div style={styles.loginContainer}>
        <Head>
          <title>Crate - Full-Stack Dashboard</title>
        </Head>
        <div style={styles.loginBox}>
          <h1 style={styles.loginTitle}>🎵 Crate</h1>
          <p style={styles.loginSubtitle}>Full-Stack Music Dashboard</p>
          <input
            type="text"
            placeholder="Enter your username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleLogin()}
            style={styles.loginInput}
          />
          <button onClick={handleLogin} style={styles.loginButton}>
            Login
          </button>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <Head>
        <title>Crate - {username}</title>
      </Head>

      {/* Sidebar */}
      <div style={styles.sidebar}>
        <div style={styles.logo}>
          <h1 style={styles.logoText}>🎵 Crate</h1>
          <p style={styles.logoSubtext}>Full-Stack</p>
        </div>

        <div style={styles.userSection}>
          <div style={styles.userAvatar}>{username[0].toUpperCase()}</div>
          <div>
            <div style={styles.userName}>{username}</div>
            <button onClick={handleLogout} style={styles.logoutButton}>
              Logout
            </button>
          </div>
        </div>

        <div style={styles.stats}>
          <div style={styles.statItem}>
            <div style={styles.statNumber}>{crate.length}</div>
            <div style={styles.statLabel}>Total Tracks</div>
          </div>
          <div style={styles.statItem}>
            <div style={styles.statNumber}>
              {new Set(crate.map(t => t.platform)).size}
            </div>
            <div style={styles.statLabel}>Platforms</div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div style={styles.mainContent}>
        <div style={styles.header}>
          <h2 style={styles.headerTitle}>Your Collection</h2>
        </div>

        <div style={styles.addSection}>
          <input
            type="text"
            value={inputUrl}
            onChange={(e) => setInputUrl(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && addToCrate()}
            placeholder="Paste a music link..."
            style={styles.addInput}
          />
          <button onClick={addToCrate} style={styles.addButton}>
            + Add Track
          </button>
        </div>

        {loading ? (
          <div style={styles.loading}>Loading...</div>
        ) : crate.length === 0 ? (
          <div style={styles.emptyState}>
            <div style={styles.emptyIcon}>🎧</div>
            <p style={styles.emptyText}>No tracks yet. Start building your crate!</p>
          </div>
        ) : (
          <div style={styles.trackList}>
            {crate.map((track, index) => (
              <div key={track.id} style={styles.trackItem}>
                <div style={styles.trackNumber}>{index + 1}</div>
                <div style={styles.trackInfo}>
                  <div style={styles.trackPlatform}>{track.platform}</div>
                  <a
                    href={track.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={styles.trackLink}
                  >
                    {track.url}
                  </a>
                </div>
                <div style={styles.trackDate}>{track.addedAt}</div>
                <button
                  onClick={() => removeTrack(track.id)}
                  style={styles.removeButton}
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

const styles = {
  loginContainer: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #1DB954 0%, #191414 100%)',
  },
  loginBox: {
    background: 'white',
    padding: '40px',
    borderRadius: '12px',
    boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
    textAlign: 'center',
    minWidth: '300px',
  },
  loginTitle: {
    fontSize: '36px',
    margin: '0 0 10px 0',
  },
  loginSubtitle: {
    color: '#666',
    marginBottom: '30px',
  },
  loginInput: {
    width: '100%',
    padding: '12px',
    border: '2px solid #ddd',
    borderRadius: '6px',
    fontSize: '16px',
    marginBottom: '15px',
  },
  loginButton: {
    width: '100%',
    padding: '12px',
    background: '#1DB954',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    fontSize: '16px',
    fontWeight: 'bold',
    cursor: 'pointer',
  },
  container: {
    display: 'flex',
    minHeight: '100vh',
    background: '#121212',
    color: 'white',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  },
  sidebar: {
    width: '280px',
    background: '#000',
    padding: '24px',
    display: 'flex',
    flexDirection: 'column',
    gap: '30px',
  },
  logo: {
    paddingBottom: '20px',
    borderBottom: '1px solid #282828',
  },
  logoText: {
    fontSize: '28px',
    margin: '0',
  },
  logoSubtext: {
    color: '#888',
    fontSize: '12px',
    margin: '5px 0 0 0',
  },
  userSection: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  userAvatar: {
    width: '48px',
    height: '48px',
    borderRadius: '50%',
    background: '#1DB954',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '20px',
    fontWeight: 'bold',
  },
  userName: {
    fontWeight: 'bold',
    marginBottom: '4px',
  },
  logoutButton: {
    background: 'transparent',
    border: '1px solid #888',
    color: '#888',
    padding: '4px 12px',
    borderRadius: '12px',
    fontSize: '12px',
    cursor: 'pointer',
  },
  stats: {
    display: 'flex',
    gap: '20px',
  },
  statItem: {
    flex: 1,
  },
  statNumber: {
    fontSize: '32px',
    fontWeight: 'bold',
    color: '#1DB954',
  },
  statLabel: {
    fontSize: '12px',
    color: '#888',
    marginTop: '4px',
  },
  mainContent: {
    flex: 1,
    padding: '24px',
    overflowY: 'auto',
  },
  header: {
    marginBottom: '24px',
  },
  headerTitle: {
    fontSize: '32px',
    margin: '0',
  },
  addSection: {
    display: 'flex',
    gap: '12px',
    marginBottom: '30px',
  },
  addInput: {
    flex: 1,
    padding: '14px',
    background: '#282828',
    border: '1px solid #404040',
    borderRadius: '6px',
    color: 'white',
    fontSize: '14px',
  },
  addButton: {
    padding: '14px 24px',
    background: '#1DB954',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    fontWeight: 'bold',
    cursor: 'pointer',
  },
  loading: {
    textAlign: 'center',
    padding: '40px',
    color: '#888',
  },
  emptyState: {
    textAlign: 'center',
    padding: '60px',
  },
  emptyIcon: {
    fontSize: '64px',
    marginBottom: '16px',
  },
  emptyText: {
    color: '#888',
    fontSize: '18px',
  },
  trackList: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  trackItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '16px',
    padding: '16px',
    background: '#181818',
    borderRadius: '6px',
    transition: 'background 0.2s',
  },
  trackNumber: {
    color: '#888',
    minWidth: '30px',
  },
  trackInfo: {
    flex: 1,
  },
  trackPlatform: {
    fontSize: '16px',
    fontWeight: 'bold',
    marginBottom: '4px',
  },
  trackLink: {
    fontSize: '13px',
    color: '#888',
    textDecoration: 'none',
  },
  trackDate: {
    fontSize: '13px',
    color: '#888',
  },
  removeButton: {
    width: '32px',
    height: '32px',
    background: 'transparent',
    border: '1px solid #404040',
    borderRadius: '50%',
    color: '#888',
    fontSize: '24px',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    lineHeight: 1,
  },
}
