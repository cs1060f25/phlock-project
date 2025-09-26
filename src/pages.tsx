import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { demoShare, tracks, userArtists, artistLeaderboards, artistActivity, mgkPlugMetrics, mgkSongMetrics } from './data'
import { useStore } from './store'
import { useEffect, useState } from 'react'
import WaveDivider from './components/WaveDivider'

// Helper function to format timestamps
function formatTimestamp(timestamp: string): string {
  const now = new Date()
  const date = new Date(timestamp)
  const diffMs = now.getTime() - date.getTime()
  const diffMinutes = Math.floor(diffMs / (1000 * 60))
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

  if (diffMinutes < 60) {
    return `${diffMinutes} minutes ago`
  } else if (diffHours < 24) {
    return `${diffHours} hour${diffHours === 1 ? '' : 's'} ago`
  } else if (diffDays === 1) {
    return 'yesterday'
  } else if (diffDays <= 7) {
    return `${diffDays} days ago`
  } else {
    return date.toLocaleDateString('en-US', { month: '2-digit', day: '2-digit', year: '2-digit' })
  }
}

// Shared bottom navigation component
function BottomNavigation({ currentPath }: { currentPath: string }) {
  // Determine the correct home route based on stored user type
  const getHomeRoute = () => {
    const userType = localStorage.getItem('userType')
    console.log('Stored user type:', userType) // Debug logging
    if (userType === 'artist') {
      console.log('Routing to artist home') // Debug logging
      return '/home-menu-artist'
    }
    console.log('Routing to fan home') // Debug logging
    return '/home-menu-fan'
  }
  
  const getUserType = () => {
    return localStorage.getItem('userType') || 'fan'
  }
  
  const homeRoute = getHomeRoute()
  
  return (
    <div style={{ borderTop: '1px solid #333', padding: '8px 16px', display: 'flex', justifyContent: 'space-around', alignItems: 'center' }}>
      <Link to={homeRoute} style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'center', 
        textDecoration: 'none', 
        color: currentPath === '/home-menu-fan' || currentPath === '/home-menu-artist' ? 'white' : '#666',
        flex: 1
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
        </svg>
        <span style={{ fontSize: '8px', marginTop: '2px' }}>Home</span>
      </Link>
      
      <Link to="/search" style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'center', 
        textDecoration: 'none', 
        color: currentPath === '/search' ? 'white' : '#666',
        flex: 1
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
        </svg>
        <span style={{ fontSize: '8px', marginTop: '2px' }}>Search</span>
      </Link>
      
      <Link to={getUserType() === 'artist' ? '/artist-profile' : '/crate'} style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'center', 
        textDecoration: 'none', 
        color: (currentPath === '/crate' || currentPath === '/artist-profile') ? 'white' : '#666',
        flex: 1
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
        </svg>
        <span style={{ fontSize: '8px', marginTop: '2px' }}>{getUserType() === 'artist' ? 'My Profile' : 'My Crate'}</span>
      </Link>
    </div>
  )
}

// Shared send button component
function SendButton() {
  return (
    <div style={{ position: 'absolute', bottom: '70px', right: '20px' }}>
      <Link to="/share" style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center', 
        width: '40px', 
        height: '40px', 
        borderRadius: '50%', 
        background: 'white', 
        border: '2px solid #333', 
        textDecoration: 'none', 
        boxShadow: '0 2px 8px rgba(0, 0, 0, 0.3)' 
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="black">
          <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
        </svg>
      </Link>
    </div>
  )
}

export function Landing() {
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ height: 40 }} />
        <WaveDivider width="90%" />
        <div style={{ height: 30 }} />
        <h1 style={{ margin: 0, fontSize: '48px' }}>Phlock</h1>
        <div style={{ height: 20 }} />
        <p style={{ color: '#9ca3af', fontSize: '18px', margin: 0 }}>heard together</p>
        <div style={{ height: 30 }} />
        <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
          <Link to="/home-menu-fan" onClick={() => localStorage.setItem('userType', 'fan')} style={{ 
            fontSize: '14px', 
            padding: '12px 20px', 
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '25px',
            fontWeight: '500',
            boxShadow: '0 4px 15px rgba(102, 126, 234, 0.4)'
          }}>
            For Fans →
          </Link>
          <Link to="/home-menu-artist" onClick={() => localStorage.setItem('userType', 'artist')} style={{ 
            fontSize: '14px', 
            padding: '12px 20px', 
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '25px',
            fontWeight: '500',
            boxShadow: '0 4px 15px rgba(102, 126, 234, 0.4)'
          }}>
            For Artists →
          </Link>
        </div>
        <div style={{ height: 30 }} />
        <WaveDivider width="90%" />
        <div style={{ height: 40 }} />
      </div>
    </div>
  )
}

// Old home page now called HomeMenu
// Fan home page - now feed-based
export function HomeMenuFan() {
  const { activity } = useStore()
  const [expandedArtist, setExpandedArtist] = useState<string | null>(null)
  
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
          <WaveDivider width="90%" />
          <div style={{ height: 20 }} />
          <h2 style={{ fontSize: '20px', margin: '0 0 16px 0', textAlign: 'center' }}>Recent Activity</h2>
          
          {activity.map((a) => {
            const getActivityText = () => {
              switch (a.type) {
                case 'share':
                  return `${a.user} sent "${a.trackTitle}" to ${a.targetUser}`
                case 'add':
                  return `${a.user} added "${a.trackTitle}" to their crate`
                case 'play':
                  return `${a.user} is playing "${a.trackTitle}"`
                default:
                  return ''
              }
            }
            
            return (
              <div key={a.id} style={{ 
                padding: '12px', 
                marginBottom: '8px',
                border: '1px solid #333', 
                borderRadius: '8px',
                background: 'rgba(255, 255, 255, 0.02)'
              }}>
                <div style={{ fontSize: '12px', color: '#9ca3af', lineHeight: '1.4' }}>{getActivityText()}</div>
                <div style={{ fontSize: '10px', color: '#666', marginTop: '4px' }}>{formatTimestamp(a.timestamp)}</div>
              </div>
            )
          })}
          
          <div style={{ height: 20 }} />
          <h2 style={{ fontSize: '18px', margin: '16px 0', textAlign: 'center' }}>Your Artists</h2>
          
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, marginBottom: '20px' }}>
            {userArtists.map((artist) => {
              const leaderboard = artistLeaderboards[artist.id]
              const isExpanded = expandedArtist === artist.id
              
              return (
                <div key={artist.id} style={{ marginBottom: '12px' }}>
                  <div 
                    style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between', 
                      alignItems: 'center',
                      padding: '8px 12px',
                      background: isExpanded ? 'rgba(255, 255, 255, 0.1)' : 'rgba(255, 255, 255, 0.05)',
                      border: '1px solid #333',
                      borderRadius: '6px',
                      cursor: 'pointer'
                    }}
                    onClick={() => setExpandedArtist(isExpanded ? null : artist.id)}
                  >
                    <div>
                      <div style={{ fontSize: '14px', fontWeight: 'bold' }}>{artist.name}</div>
                      <div style={{ fontSize: '10px', color: '#9ca3af' }}>You're #{artist.userPosition}</div>
                    </div>
                    <div style={{ fontSize: '12px', color: '#666' }}>
                      {isExpanded ? '▼' : '▶'}
                    </div>
                  </div>
                  
                  {isExpanded && (
                    <div style={{ 
                      marginTop: '8px', 
                      padding: '8px 12px', 
                      background: 'rgba(255, 255, 255, 0.02)',
                      border: '1px solid #333',
                      borderRadius: '6px',
                      maxHeight: '150px',
                      overflowY: 'auto'
                    }}>
                      <ol style={{ margin: 0, padding: 0, fontSize: '12px', lineHeight: '1.4' }}>
                        {leaderboard.slice(0, 8).map((p, i) => (
                          <li key={i} style={{ 
                            margin: '4px 0', 
                            padding: '2px 0',
                            display: 'flex',
                            justifyContent: 'space-between',
                            color: p.user === 'sarah' ? '#4f46e5' : 'inherit'
                          }}>
                            <span>#{i + 1} {p.user}</span>
                            <span style={{ color: '#666' }}>{p.score}</span>
                          </li>
                        ))}
                      </ol>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
          
          <WaveDivider width="90%" />
        </div>
        
        <BottomNavigation currentPath="/home-menu-fan" />
        <SendButton />
      </div>
    </div>
  )
}

// Artist home page - now feed-based with artist dashboard
export function HomeMenuArtist() {
  const [likedActivities, setLikedActivities] = useState<Set<string>>(new Set())
  const [commentingOn, setCommentingOn] = useState<string | null>(null)
  const [commentText, setCommentText] = useState('')
  
  const handleLike = (activityId: string) => {
    setLikedActivities(prev => {
      const newSet = new Set(prev)
      if (newSet.has(activityId)) {
        newSet.delete(activityId)
      } else {
        newSet.add(activityId)
      }
      return newSet
    })
  }
  
  const handleComment = (activityId: string) => {
    if (commentingOn === activityId) {
      setCommentingOn(null)
      setCommentText('')
    } else {
      setCommentingOn(activityId)
      setCommentText('')
    }
  }
  
  const handleCommentSubmit = (activityId: string) => {
    if (commentText.trim()) {
      console.log(`Comment on ${activityId}: ${commentText}`)
      setCommentingOn(null)
      setCommentText('')
    }
  }
  
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
          <WaveDivider width="90%" />
          <div style={{ height: 20 }} />
          <h2 style={{ fontSize: '20px', margin: '0 0 16px 0', textAlign: 'center' }}>mgk activity</h2>
          
          {artistActivity.map((a) => {
            const getActivityText = () => {
              switch (a.type) {
                case 'share':
                  return `${a.user} sent "${a.trackTitle}" to ${a.targetUser}`
                case 'add':
                  return `${a.user} added "${a.trackTitle}" to their crate`
                case 'play':
                  return `${a.user} is playing "${a.trackTitle}"`
                default:
                  return ''
              }
            }
            
            const isLiked = likedActivities.has(a.id)
            const isCommenting = commentingOn === a.id
            
            return (
              <div key={a.id} style={{ 
                padding: '12px', 
                marginBottom: '8px',
                border: '1px solid #333', 
                borderRadius: '8px',
                background: 'rgba(255, 255, 255, 0.02)'
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between'
                }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: '12px', color: '#9ca3af', lineHeight: '1.4' }}>{getActivityText()}</div>
                    <div style={{ fontSize: '10px', color: '#666', marginTop: '4px' }}>{formatTimestamp(a.timestamp)}</div>
                  </div>
                  <div style={{ display: 'flex', gap: '8px', marginLeft: '12px' }}>
                    <button 
                      onClick={() => handleLike(a.id)}
                      style={{
                        width: '24px',
                        height: '24px',
                        borderRadius: '50%',
                        border: isLiked ? '1px solid white' : '1px solid #333',
                        background: isLiked ? 'white' : 'rgba(255, 255, 255, 0.05)',
                        color: isLiked ? 'black' : 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        fontSize: '10px',
                        filter: isLiked ? 'none' : 'grayscale(100%) brightness(0.8)'
                      }}
                      title="Like"
                    >
                      👍
                    </button>
                    <button 
                      onClick={() => handleComment(a.id)}
                      style={{
                        width: '24px',
                        height: '24px',
                        borderRadius: '50%',
                        border: isCommenting ? '1px solid white' : '1px solid #333',
                        background: isCommenting ? 'white' : 'rgba(255, 255, 255, 0.05)',
                        color: isCommenting ? 'black' : 'white',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        fontSize: '10px',
                        filter: isCommenting ? 'none' : 'grayscale(100%) brightness(0.8)'
                      }}
                      title="Comment"
                    >
                      💬
                    </button>
                  </div>
                </div>
                
                {isCommenting && (
                  <div style={{
                    marginTop: '12px',
                    padding: '8px',
                    border: '1px solid #333',
                    borderRadius: '6px',
                    background: 'rgba(255, 255, 255, 0.02)'
                  }}>
                    <input
                      type="text"
                      value={commentText}
                      onChange={(e) => setCommentText(e.target.value)}
                      placeholder="say thanks..."
                      style={{
                        width: '100%',
                        background: 'transparent',
                        border: 'none',
                        color: 'white',
                        fontSize: '12px',
                        outline: 'none',
                        padding: '4px 0'
                      }}
                      onKeyPress={(e) => {
                        if (e.key === 'Enter') {
                          handleCommentSubmit(a.id)
                        }
                      }}
                    />
                    <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                      <button
                        onClick={() => handleCommentSubmit(a.id)}
                        style={{
                          fontSize: '10px',
                          padding: '4px 8px',
                          background: 'rgba(255, 255, 255, 0.1)',
                          color: 'white',
                          border: '1px solid #333',
                          borderRadius: '4px',
                          cursor: 'pointer'
                        }}
                      >
                        Send
                      </button>
                      <button
                        onClick={() => {
                          setCommentingOn(null)
                          setCommentText('')
                        }}
                        style={{
                          fontSize: '10px',
                          padding: '4px 8px',
                          background: 'transparent',
                          color: '#9ca3af',
                          border: '1px solid #333',
                          borderRadius: '4px',
                          cursor: 'pointer'
                        }}
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
          
          <div style={{ height: 20 }} />
          <h2 style={{ fontSize: '18px', margin: '16px 0', textAlign: 'center' }}>mgk Dashboard</h2>
          
          <section style={{ marginBottom: 12 }}>
            <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '16px' }}>Top Plugs</h3>
              <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
                {mgkPlugMetrics.slice(0, 10).map((p, i) => (
                  <div key={i} style={{ 
                    margin: '6px 0', 
                    padding: '6px 8px', 
                    background: 'rgba(255, 255, 255, 0.02)', 
                    borderRadius: '4px',
                    border: '1px solid #333'
                  }}>
                    <div style={{ fontWeight: '500', marginBottom: '2px' }}>{p.user}</div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: '#9ca3af' }}>
                      <span>{p.totalSends} sends</span>
                      <span>{p.crateAdditions} saves</span>
                      <span>{p.forwardShares} forwards</span>
                    </div>
                    <div style={{ fontSize: '9px', color: '#666', marginTop: '2px' }}>
                      {p.uniqueRecipients} unique people reached
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section style={{ marginBottom: 12 }}>
            <div style={{ padding: 10, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '14px' }}>Fan Rewards</h3>
              <div style={{ display: 'flex', gap: 6, justifyContent: 'center', flexWrap: 'wrap' }}>
                <button onClick={() => alert('🎵 Sending unreleased track preview to top fans...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎵 Early Access</button>
                <button onClick={() => alert('🎫 Granting VIP meet & greet access...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎫 Meet & Greet</button>
                <button onClick={() => alert('📱 Adding to exclusive fan group chat...')} style={{ fontSize: '10px', padding: '6px 8px' }}>📱 Fan Group</button>
                <button onClick={() => alert('🎨 Sending signed merchandise...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎨 Signed Merch</button>
                <button onClick={() => alert('🎤 Inviting to private studio session...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎤 Studio Visit</button>
                <button onClick={() => alert('💬 Sending personal thank you message...')} style={{ fontSize: '10px', padding: '6px 8px' }}>💬 Thank You</button>
              </div>
            </div>
          </section>

          <section>
            <div style={{ padding: 10, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '14px' }}>Sharing Insights</h3>
              <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Top Cities:</span><br/>
                  <span style={{ color: '#9ca3af' }}>Cleveland (47), Los Angeles (32), New York (28)</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Peak Hours:</span><br/>
                  <span style={{ color: '#9ca3af' }}>9-11 PM weekdays, 6-8 PM weekends</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Conversion Rate:</span><br/>
                  <span style={{ color: '#9ca3af' }}>42% of shares result in saves</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Virality Score:</span><br/>
                  <span style={{ color: '#9ca3af' }}>3.1x average forward shares</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Top Tracks:</span><br/>
                  <span style={{ color: '#9ca3af' }}>Bloody Valentine (67%), My Ex's Best Friend (23%)</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Demographics:</span><br/>
                  <span style={{ color: '#9ca3af' }}>72% 16-28, 58% alternative/punk fans</span>
                </div>
                <div>
                  <span style={{ fontWeight: 'bold' }}>Engagement:</span><br/>
                  <span style={{ color: '#9ca3af' }}>High share rate during tour dates (+89%)</span>
                </div>
              </div>
            </div>
          </section>
          
          <WaveDivider width="90%" />
        </div>
        
        <BottomNavigation currentPath="/home-menu-artist" />
        <SendButton />
      </div>
    </div>
  )
}


export function Search() {
  const [searchQuery, setSearchQuery] = useState('')
  
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ flex: 1, padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
          <WaveDivider width="90%" />
          <div style={{ height: 20 }} />
          <h2 style={{ fontSize: '20px', margin: '0 0 20px 0', textAlign: 'center' }}>Search</h2>
          
          {/* Search Input */}
          <div style={{ position: 'relative', marginBottom: '20px' }}>
            <input
              type="text"
              placeholder="What do you want to send?"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                width: '100%',
                padding: '12px 16px',
                fontSize: '14px',
                background: 'rgba(255, 255, 255, 0.1)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                borderRadius: '25px',
                color: 'white',
                outline: 'none',
                boxSizing: 'border-box'
              }}
            />
            <div style={{
              position: 'absolute',
              right: '16px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#9ca3af'
            }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
              </svg>
            </div>
          </div>
          
          {/* Search Results Placeholder */}
          {searchQuery ? (
            <div style={{ textAlign: 'center', color: '#9ca3af', fontSize: '12px' }}>
              <p>Search results for "{searchQuery}"</p>
              <p style={{ marginTop: '8px' }}>Search functionality coming soon</p>
            </div>
          ) : (
            <div style={{ textAlign: 'center', color: '#9ca3af', fontSize: '12px' }}>
              <p>Start typing to search for music</p>
            </div>
          )}
          
          <WaveDivider width="90%" />
        </div>
        
        <BottomNavigation currentPath="/search" />
        <SendButton />
      </div>
    </div>
  )
}

export function Receive() {
  const { id } = useParams()
  const share = id === demoShare.id ? demoShare : demoShare
  const track = tracks[share.trackId]
  const { addToCrate } = useStore()
  const [playing, setPlaying] = useState(false)
  const [progress, setProgress] = useState(0)
  const nav = useNavigate()

  useEffect(() => {
    setPlaying(true)
    const total = 30
    let t = 0
    const timer = setInterval(() => {
      t += 1
      setProgress(Math.min(100, Math.round((t / total) * 100)))
      if (t >= total) { clearInterval(timer); setPlaying(false) }
    }, 150)
    return () => clearInterval(timer)
  }, [])

  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ position: 'relative' }}>
        <div style={{ textAlign: 'center', padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
          <WaveDivider width="90%" />
        </div>
        <p style={{ color: '#666', fontSize: '14px', textAlign: 'center' }}>From {share.fromUser} → To {share.toUser}</p>
        <section style={{ marginTop: 16, flex: 1, padding: '20px', maxWidth: '260px', margin: '16px auto' }}>
          <div style={{ padding: 16, border: '1px solid #eee', borderRadius: 12, height: 'calc(100vh - 300px)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <div style={{ display: 'grid', gap: 12, justifyItems: 'center' }}>
              <img src={track.artwork} width={120} height={120} style={{ borderRadius: 12 }} />
        <div>
                <h2 style={{ margin: '8px 0', fontSize: '18px' }}>{track.title}</h2>
                <p style={{ margin: 0, fontSize: '14px' }}>{track.artist}</p>
              </div>
              <div style={{ height: 6, background: '#eee', borderRadius: 3, width: '100%' }}>
                <div style={{ width: `${progress}%`, height: 6, background: '#4f46e5', borderRadius: 3 }} />
              </div>
              <p style={{ fontSize: '10px', color: '#666', margin: 0 }}>{playing ? 'Preview playing…' : 'Preview finished'}</p>
              <div style={{ display: 'flex', gap: 6, justifyContent: 'center', flexWrap: 'wrap' }}>
                <button onClick={() => { addToCrate(share) }} style={{ fontSize: '10px', padding: '6px 10px' }}>Add to Crate</button>
                <button onClick={() => alert('Open in Apple/Spotify - not implemented')} style={{ fontSize: '10px', padding: '6px 10px' }}>Open in App</button>
                <button onClick={() => nav('/share?trackId=' + track.id)} style={{ fontSize: '10px', padding: '6px 10px' }}>Share Forward</button>
              </div>
          </div>
          </div>
        </section>
        <div style={{ marginTop: 12, textAlign: 'center' }}>
          <Link to="/crate" style={{ fontSize: '12px' }}>Go to My Crate</Link>
        </div>
        <WaveDivider width="90%" />
        <BottomNavigation currentPath="/r/demo" />
        <SendButton />
      </div>
    </div>
  )
}

export function Crate() {
  const { crate, inbox } = useStore()
  
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ padding: '20px', maxWidth: '260px', margin: '0 auto', textAlign: 'center' }}>
        </div>
        <WaveDivider width="90%" />
        
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px', maxWidth: '260px', margin: '0 auto' }}>
          {/* Inbox Section */}
          <div style={{ marginBottom: '24px' }}>
            <h2 style={{ fontSize: '18px', textAlign: 'center', margin: '16px 0' }}>Inbox ({inbox.length})</h2>
            <p style={{ fontSize: '10px', color: '#9ca3af', textAlign: 'center', margin: '0 0 16px 0' }}>
              Swipe right to add to crate, left to remove
            </p>
            <ul style={{ listStyle: 'none', padding: 0 }}>
              {inbox.map((item, i) => {
                const t = tracks[item.trackId]
                return (
                  <li key={i} style={{ margin: '6px 0' }}>
                    <div style={{ 
                      padding: 8, 
                      border: '1px solid #333', 
                      borderRadius: 6, 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: 8,
                      background: 'rgba(255, 255, 255, 0.02)'
                    }}>
                      <div style={{ position: 'relative' }}>
                        <img src={t.artwork} width={40} height={40} style={{ borderRadius: 4 }} />
                        <div style={{
                          position: 'absolute',
                          top: '50%',
                          left: '50%',
                          transform: 'translate(-50%, -50%)',
                          width: '16px',
                          height: '16px',
                          borderRadius: '50%',
                          background: 'rgba(0, 0, 0, 0.7)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: 'pointer'
                        }}>
                          <div style={{
                            width: 0,
                            height: 0,
                            borderLeft: '6px solid white',
                            borderTop: '4px solid transparent',
                            borderBottom: '4px solid transparent',
                            marginLeft: '2px'
                          }} />
                        </div>
                      </div>
                      <div style={{ flex: 1, textAlign: 'left' }}>
                        <div style={{ fontSize: '12px', fontWeight: '500', marginBottom: '2px' }}>{t.title}</div>
                        <div style={{ color: '#9ca3af', fontSize: '10px' }}>{t.artist}</div>
                      </div>
                      <div style={{ textAlign: 'right', minWidth: '60px' }}>
                        <div style={{ color: '#666', fontSize: '8px', marginBottom: '2px' }}>from {item.fromUser}</div>
                      </div>
                    </div>
                  </li>
                )
              })}
            </ul>
          </div>
          
          {/* Crate Section */}
          <div>
            <h2 style={{ fontSize: '18px', textAlign: 'center', margin: '16px 0' }}>My Crate ({crate.length})</h2>
      <ul style={{ listStyle: 'none', padding: 0 }}>
        {crate.map((c, i) => {
          const t = tracks[c.trackId]
          return (
                    <li key={i} style={{ margin: '6px 0' }}>
                      <div style={{ padding: 8, border: '1px solid #333', borderRadius: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ position: 'relative' }}>
                          <img src={t.artwork} width={40} height={40} style={{ borderRadius: 4 }} />
                          <div style={{
                            position: 'absolute',
                            top: '50%',
                            left: '50%',
                            transform: 'translate(-50%, -50%)',
                            width: '16px',
                            height: '16px',
                            borderRadius: '50%',
                            background: 'rgba(0, 0, 0, 0.7)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            cursor: 'pointer'
                          }}>
                            <div style={{
                              width: 0,
                              height: 0,
                              borderLeft: '6px solid white',
                              borderTop: '4px solid transparent',
                              borderBottom: '4px solid transparent',
                              marginLeft: '2px'
                            }} />
                          </div>
                        </div>
                        <div style={{ flex: 1, textAlign: 'left' }}>
                          <div style={{ fontSize: '12px', fontWeight: '500', marginBottom: '2px' }}>{t.title}</div>
                          <div style={{ color: '#9ca3af', fontSize: '10px' }}>{t.artist}</div>
                        </div>
                        <div style={{ textAlign: 'right', minWidth: '60px' }}>
                          <div style={{ color: '#666', fontSize: '8px', marginBottom: '2px' }}>from {c.fromUser}</div>
                          <Link to={'/share?trackId=' + t.id} style={{ fontSize: '8px', color: '#6d7fff' }}>Share</Link>
                        </div>
              </div>
            </li>
          )
        })}
      </ul>
          </div>
        </div>
        <WaveDivider width="90%" />
        <BottomNavigation currentPath="/crate" />
        <SendButton />
      </div>
    </div>
  )
}

export function Share() {
  const [params] = useSearchParams()
  const trackId = params.get('trackId') || 't1'
  const t = tracks[trackId]
  const { forwardShare } = useStore()
  const [to, setTo] = useState('')
  const [limitUsed, setLimitUsed] = useState(false)

  const send = () => {
    if (limitUsed) { alert('Daily limit reached for this friend'); return }
    if (!to.trim()) { alert('Enter a friend username'); return }
    forwardShare(trackId, to.trim())
    setLimitUsed(true)
    alert(`Sent ${t.title} to ${to}`)
  }

  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ position: 'relative' }}>
        <div style={{ textAlign: 'center', padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
        </div>
        <WaveDivider width="90%" />
        <h2 style={{ fontSize: '20px', textAlign: 'center' }}>Sonic Send</h2>
        <section style={{ marginTop: 16, flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '20px', maxWidth: '260px', margin: '16px auto' }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ display: 'grid', gap: 8, justifyItems: 'center' }}>
        <img src={t.artwork} width={80} height={80} style={{ borderRadius: 8 }} />
              <div style={{ fontSize: '14px' }}>{t.title} — {t.artist}</div>
              <div style={{ display: 'flex', gap: 6, width: '100%' }}>
                <input 
                  placeholder="Friend username" 
                  value={to} 
                  onChange={(e) => setTo(e.target.value)} 
                  style={{ fontSize: '10px', padding: '6px 8px', flex: 1 }} 
                />
                <button onClick={send} style={{ fontSize: '10px', padding: '6px 8px' }}>Send</button>
              </div>
            </div>
      </div>
        </section>
        <p style={{ fontSize: 10, color: '#666', textAlign: 'center' }}>Limit: one song per friend per day</p>
        <WaveDivider width="90%" />
        <SendButton />
      </div>
    </div>
  )
}

export function Leaderboard() {
  const [expandedArtist, setExpandedArtist] = useState<string | null>(null)
  
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ padding: '20px', maxWidth: '260px', margin: '0 auto', textAlign: 'center' }}>
        </div>
        <WaveDivider width="90%" />
        <h2 style={{ fontSize: '18px', textAlign: 'center', margin: '16px 0' }}>Your Artists</h2>
        <section style={{ marginTop: 8, flex: 1, padding: '0 20px', maxWidth: '260px', margin: '8px auto' }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8, height: 'calc(100vh - 250px)', overflowY: 'auto' }}>
            {userArtists.map((artist) => {
              const leaderboard = artistLeaderboards[artist.id]
              const isExpanded = expandedArtist === artist.id
              
              return (
                <div key={artist.id} style={{ marginBottom: '12px' }}>
                  <div 
                    style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between', 
                      alignItems: 'center',
                      padding: '8px 12px',
                      background: isExpanded ? 'rgba(255, 255, 255, 0.1)' : 'rgba(255, 255, 255, 0.05)',
                      border: '1px solid #333',
                      borderRadius: '6px',
                      cursor: 'pointer'
                    }}
                    onClick={() => setExpandedArtist(isExpanded ? null : artist.id)}
                  >
                    <div>
                      <div style={{ fontSize: '14px', fontWeight: 'bold' }}>{artist.name}</div>
                      <div style={{ fontSize: '10px', color: '#9ca3af' }}>You're #{artist.userPosition}</div>
                    </div>
                    <div style={{ fontSize: '12px', color: '#666' }}>
                      {isExpanded ? '▼' : '▶'}
                    </div>
                  </div>
                  
                  {isExpanded && (
                    <div style={{ 
                      marginTop: '8px', 
                      padding: '8px 12px', 
                      background: 'rgba(255, 255, 255, 0.02)',
                      border: '1px solid #333',
                      borderRadius: '6px',
                      maxHeight: '200px',
                      overflowY: 'auto'
                    }}>
                      <ol style={{ margin: 0, padding: 0, fontSize: '12px', lineHeight: '1.4' }}>
        {leaderboard.map((p, i) => (
                          <li key={i} style={{ 
                            margin: '4px 0', 
                            padding: '2px 0',
                            display: 'flex',
                            justifyContent: 'space-between',
                            color: p.user === 'sarah' ? '#4f46e5' : 'inherit'
                          }}>
                            <span>#{i + 1} {p.user}</span>
                            <span style={{ color: '#666' }}>{p.score}</span>
                          </li>
        ))}
      </ol>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </section>
        <p style={{ color: '#666', fontSize: 10, margin: '8px 0', textAlign: 'center' }}>Save = +10, Forward = +5 (demo)</p>
        <WaveDivider width="90%" />
        <BottomNavigation currentPath="/leaderboard/mkgee" />
        <SendButton />
      </div>
    </div>
  )
}

export function ArtistDashboard() {
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ padding: '20px', maxWidth: '260px', margin: '0 auto', textAlign: 'center' }}>
        </div>
        <WaveDivider width="90%" />
        <h2 style={{ fontSize: '18px', textAlign: 'center', margin: '16px 0' }}>mgk Dashboard</h2>

        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px', maxWidth: '260px', margin: '0 auto' }}>
          <section style={{ marginBottom: 12 }}>
        <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '16px' }}>Top Plugs</h3>
              <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
                {mgkPlugMetrics.slice(0, 10).map((p, i) => (
                  <div key={i} style={{ 
                    margin: '6px 0', 
                    padding: '6px 8px', 
                    background: 'rgba(255, 255, 255, 0.02)', 
                    borderRadius: '4px',
                    border: '1px solid #333'
                  }}>
                    <div style={{ fontWeight: '500', marginBottom: '2px' }}>{p.user}</div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: '#9ca3af' }}>
                      <span>{p.totalSends} sends</span>
                      <span>{p.crateAdditions} saves</span>
                      <span>{p.forwardShares} forwards</span>
                    </div>
                    <div style={{ fontSize: '9px', color: '#666', marginTop: '2px' }}>
                      {p.uniqueRecipients} unique people reached
                    </div>
                  </div>
                ))}
              </div>
        </div>
          </section>

          <section style={{ marginBottom: 12 }}>
            <div style={{ padding: 10, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '14px' }}>Fan Rewards</h3>
              <div style={{ display: 'flex', gap: 6, justifyContent: 'center', flexWrap: 'wrap' }}>
                <button onClick={() => alert('🎵 Sending unreleased track preview to top fans...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎵 Early Access</button>
                <button onClick={() => alert('🎫 Granting VIP meet & greet access...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎫 Meet & Greet</button>
                <button onClick={() => alert('📱 Adding to exclusive fan group chat...')} style={{ fontSize: '10px', padding: '6px 8px' }}>📱 Fan Group</button>
                <button onClick={() => alert('🎨 Sending signed merchandise...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎨 Signed Merch</button>
                <button onClick={() => alert('🎤 Inviting to private studio session...')} style={{ fontSize: '10px', padding: '6px 8px' }}>🎤 Studio Visit</button>
                <button onClick={() => alert('💬 Sending personal thank you message...')} style={{ fontSize: '10px', padding: '6px 8px' }}>💬 Thank You</button>
              </div>
        </div>
      </section>

          <section>
            <div style={{ padding: 10, border: '1px solid #eee', borderRadius: 8 }}>
              <h3 style={{ marginTop: 0, fontSize: '14px' }}>Sharing Insights</h3>
              <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Top Cities:</span><br/>
                  <span style={{ color: '#9ca3af' }}>Cleveland (47), Los Angeles (32), New York (28)</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Peak Hours:</span><br/>
                  <span style={{ color: '#9ca3af' }}>9-11 PM weekdays, 6-8 PM weekends</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Conversion Rate:</span><br/>
                  <span style={{ color: '#9ca3af' }}>42% of shares result in saves</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Virality Score:</span><br/>
                  <span style={{ color: '#9ca3af' }}>3.1x average forward shares</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Top Tracks:</span><br/>
                  <span style={{ color: '#9ca3af' }}>Bloody Valentine (67%), My Ex's Best Friend (23%)</span>
                </div>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ fontWeight: 'bold' }}>Demographics:</span><br/>
                  <span style={{ color: '#9ca3af' }}>72% 16-28, 58% alternative/punk fans</span>
                </div>
                <div>
                  <span style={{ fontWeight: 'bold' }}>Engagement:</span><br/>
                  <span style={{ color: '#9ca3af' }}>High share rate during tour dates (+89%)</span>
                </div>
              </div>
            </div>
      </section>
        </div>
        
        <WaveDivider width="90%" />
        <BottomNavigation currentPath="/artist/mkgee/dashboard" />
        <SendButton />
      </div>
    </div>
  )
}

export function ArtistProfile() {
  return (
    <div className="phone-frame">
      <div className="phone-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
        <div style={{ flex: 1, overflowY: 'auto', padding: '20px', maxWidth: '260px', margin: '0 auto' }}>
          <WaveDivider width="90%" />
          <div style={{ height: 20 }} />
          
          {/* Artist Profile Header */}
          <div style={{ textAlign: 'center', marginBottom: '24px' }}>
            <img 
              src="https://drive.google.com/thumbnail?id=1wcZsBHjngaTqQgeNhl8ec_69FOLrmeHo&sz=w240" 
              alt="mgk" 
              style={{ 
                width: '120px', 
                height: '120px', 
                borderRadius: '50%', 
                objectFit: 'cover',
                marginBottom: '12px',
                border: '3px solid #333'
              }} 
            />
            <h1 style={{ fontSize: '24px', margin: '0 0 4px 0', fontWeight: '700' }}>mgk</h1>
            <p style={{ color: '#9ca3af', fontSize: '14px', margin: '0' }}>Artist</p>
          </div>

          {/* Top Songs Section */}
          <section style={{ marginBottom: 20 }}>
            <h2 style={{ fontSize: '18px', margin: '0 0 12px 0', textAlign: 'center' }}>Top Songs</h2>
            <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
              {mgkSongMetrics.map((song, i) => {
                const track = tracks[song.trackId]
                return (
                  <div key={i} style={{ 
                    margin: '8px 0', 
                    padding: '8px', 
                    background: 'rgba(255, 255, 255, 0.02)', 
                    borderRadius: '6px',
                    border: '1px solid #333',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '12px'
                  }}>
                    <div style={{ 
                      width: '40px', 
                      height: '40px', 
                      borderRadius: '4px',
                      background: 'linear-gradient(45deg, #667eea, #764ba2)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '12px',
                      fontWeight: 'bold',
                      color: 'white'
                    }}>
                      {i + 1}
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: '500', marginBottom: '2px' }}>{track.title}</div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: '#9ca3af' }}>
                        <span>{song.totalShares} shares</span>
                        <span>{song.crateAdditions} saves</span>
                        <span>{song.forwardShares} forwards</span>
                      </div>
                      <div style={{ fontSize: '9px', color: '#666', marginTop: '2px' }}>
                        {song.uniqueSharingUsers} fans • {song.avgSharesPerUser.toFixed(1)} avg per fan
                      </div>
                    </div>
                  </div>
                )
              })}
            </div>
          </section>

          {/* Top Plugs Section */}
          <section style={{ marginBottom: 20 }}>
            <h2 style={{ fontSize: '18px', margin: '0 0 12px 0', textAlign: 'center' }}>Top Plugs</h2>
            <div style={{ fontSize: '11px', lineHeight: '1.4' }}>
              {mgkPlugMetrics.slice(0, 10).map((plug, i) => (
                <div key={i} style={{ 
                  margin: '6px 0', 
                  padding: '8px', 
                  background: 'rgba(255, 255, 255, 0.02)', 
                  borderRadius: '6px',
                  border: '1px solid #333',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div style={{ 
                      width: '24px', 
                      height: '24px', 
                      borderRadius: '50%',
                      background: 'linear-gradient(45deg, #667eea, #764ba2)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '10px',
                      fontWeight: 'bold',
                      color: 'white'
                    }}>
                      {i + 1}
                    </div>
                    <span style={{ fontWeight: '500' }}>{plug.user}</span>
                  </div>
                  <div style={{ 
                    background: 'rgba(102, 126, 234, 0.2)', 
                    padding: '2px 8px', 
                    borderRadius: '12px',
                    fontSize: '10px',
                    color: '#667eea',
                    fontWeight: '500'
                  }}>
                    {plug.totalSends + plug.crateAdditions + plug.forwardShares}
                  </div>
                </div>
              ))}
            </div>
          </section>
          
          <WaveDivider width="90%" />
        </div>
        
        <BottomNavigation currentPath="/artist-profile" />
        <SendButton />
      </div>
    </div>
  )
}