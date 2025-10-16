import { useState, useEffect, useRef } from 'react'
import './App.css'

function App() {
  const [crate, setCrate] = useState([])
  const [messages, setMessages] = useState([
    {
      type: 'bot',
      text: 'Welcome to Crate Chat! I can help you manage your music collection.',
      timestamp: new Date()
    },
    {
      type: 'bot',
      text: 'Commands:\n• add [url] - Add a music link\n• show - Show your crate\n• remove [number] - Remove a track\n• help - Show commands\n• clear - Clear chat history',
      timestamp: new Date()
    }
  ])
  const [input, setInput] = useState('')
  const messagesEndRef = useRef(null)

  // Load crate from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('chatCrate')
    if (saved) {
      setCrate(JSON.parse(saved))
    }
  }, [])

  // Save crate to localStorage
  useEffect(() => {
    localStorage.setItem('chatCrate', JSON.stringify(crate))
  }, [crate])

  // Auto scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  // Parse URL to detect platform
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

  // Process user command
  const processCommand = (input) => {
    const trimmed = input.trim().toLowerCase()

    // Add user message
    const userMsg = {
      type: 'user',
      text: input,
      timestamp: new Date()
    }
    setMessages(prev => [...prev, userMsg])

    let botResponse = ''

    // Parse commands
    if (trimmed.startsWith('add ')) {
      const url = input.substring(4).trim()
      const track = parseUrl(url)

      if (track) {
        setCrate(prev => [...prev, track])
        botResponse = `✓ Added ${track.platform} track to your crate! You now have ${crate.length + 1} tracks.`
      } else {
        botResponse = '✗ Invalid music link. Please provide a valid URL from Spotify, Apple Music, YouTube, SoundCloud, Tidal, or Amazon Music.'
      }
    } else if (trimmed === 'show' || trimmed === 'list') {
      if (crate.length === 0) {
        botResponse = 'Your crate is empty. Use "add [url]" to add tracks.'
      } else {
        let list = `You have ${crate.length} track(s):\n\n`
        crate.forEach((track, index) => {
          list += `${index + 1}. ${track.platform} - Added ${track.addedAt}\n   ${track.url}\n\n`
        })
        botResponse = list
      }
    } else if (trimmed.startsWith('remove ')) {
      const numStr = trimmed.substring(7).trim()
      const num = parseInt(numStr)

      if (isNaN(num) || num < 1 || num > crate.length) {
        botResponse = `✗ Invalid track number. Please specify a number between 1 and ${crate.length}.`
      } else {
        const removed = crate[num - 1]
        setCrate(prev => prev.filter((_, i) => i !== num - 1))
        botResponse = `✓ Removed track #${num} (${removed.platform}) from your crate.`
      }
    } else if (trimmed === 'help') {
      botResponse = 'Available commands:\n• add [url] - Add a music link to your crate\n• show - Display all tracks in your crate\n• remove [number] - Remove a track by its number\n• clear - Clear chat history\n• help - Show this help message'
    } else if (trimmed === 'clear') {
      setMessages([{
        type: 'bot',
        text: 'Chat history cleared.',
        timestamp: new Date()
      }])
      return
    } else {
      botResponse = '✗ Unknown command. Type "help" to see available commands.'
    }

    // Add bot response
    const botMsg = {
      type: 'bot',
      text: botResponse,
      timestamp: new Date()
    }
    setMessages(prev => [...prev, botMsg])
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!input.trim()) return

    processCommand(input)
    setInput('')
  }

  return (
    <div className="chat-container">
      {/* Chat Header */}
      <div className="chat-header">
        <h1>🎵 Crate Chat</h1>
        <p>Command-line style music manager</p>
      </div>

      {/* Messages */}
      <div className="messages">
        {messages.map((msg, index) => (
          <div key={index} className={`message ${msg.type}`}>
            <div className="message-header">
              <span className="sender">{msg.type === 'user' ? 'You' : 'Crate Bot'}</span>
              <span className="time">{msg.timestamp.toLocaleTimeString()}</span>
            </div>
            <div className="message-text">{msg.text}</div>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <form onSubmit={handleSubmit} className="chat-input">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Type a command... (try 'help')"
          autoFocus
        />
        <button type="submit">Send</button>
      </form>
    </div>
  )
}

export default App
