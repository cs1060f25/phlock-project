import fs from 'fs'
import path from 'path'

const DATA_FILE = path.join(process.cwd(), 'data.json')

// Initialize data file if it doesn't exist
function initDataFile() {
  if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify({ users: {} }, null, 2))
  }
}

// Read data
function readData() {
  initDataFile()
  const data = fs.readFileSync(DATA_FILE, 'utf8')
  return JSON.parse(data)
}

// Write data
function writeData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2))
}

export default function handler(req, res) {
  const { method } = req

  try {
    if (method === 'GET') {
      // Get user's crate
      const { user } = req.query
      if (!user) {
        return res.status(400).json({ error: 'User required' })
      }

      const data = readData()
      const userCrate = data.users[user] || []

      return res.status(200).json({ tracks: userCrate })
    } else if (method === 'POST') {
      // Add track to crate
      const { user, platform, url } = req.body

      if (!user || !platform || !url) {
        return res.status(400).json({ error: 'Missing required fields' })
      }

      const data = readData()

      if (!data.users[user]) {
        data.users[user] = []
      }

      const newTrack = {
        id: Date.now(),
        platform,
        url,
        addedAt: new Date().toLocaleDateString()
      }

      data.users[user].unshift(newTrack)
      writeData(data)

      return res.status(201).json({ success: true, track: newTrack })
    } else if (method === 'DELETE') {
      // Remove track from crate
      const { user, id } = req.body

      if (!user || !id) {
        return res.status(400).json({ error: 'Missing required fields' })
      }

      const data = readData()

      if (!data.users[user]) {
        return res.status(404).json({ error: 'User not found' })
      }

      data.users[user] = data.users[user].filter(track => track.id !== id)
      writeData(data)

      return res.status(200).json({ success: true })
    } else {
      return res.status(405).json({ error: 'Method not allowed' })
    }
  } catch (error) {
    console.error('API Error:', error)
    return res.status(500).json({ error: 'Internal server error' })
  }
}
