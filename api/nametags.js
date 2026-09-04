// Vercel Serverless Function for Prism Nametag System
// Handles GET (read) and POST (write) requests for nametag data

const fs = require('fs').promises;
const path = require('path');

const DATA_FILE = path.join(__dirname, '..', 'data', 'nametags.json');

// Initialize data file if it doesn't exist
async function initDataFile() {
  try {
    await fs.access(DATA_FILE);
  } catch {
    await fs.mkdir(path.dirname(DATA_FILE), { recursive: true });
    await fs.writeFile(DATA_FILE, JSON.stringify({ users: [], lastUpdated: null }, null, 2));
  }
}

export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  await initDataFile();

  try {
    if (req.method === 'GET') {
      // Read nametag data
      const data = await fs.readFile(DATA_FILE, 'utf8');
      const parsed = JSON.parse(data);
      
      console.log('[DEBUG] Reading nametag data:', {
        userCount: parsed.users?.length || 0,
        lastUpdated: parsed.lastUpdated
      });
      
      return res.status(200).json({
        success: true,
        data: parsed
      });
    } else if (req.method === 'POST') {
      // Write/update nametag data
      const { username, displayName, userId, jobId, serverId } = req.body;
      
      console.log('[DEBUG] Received nametag data:', {
        username,
        displayName,
        userId,
        jobId,
        serverId
      });
      
      if (!username || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: username and userId'
        });
      }
      
      // Read existing data
      const data = await fs.readFile(DATA_FILE, 'utf8');
      const parsed = JSON.parse(data);
      
      // Check if user already exists and update, or add new
      const existingIndex = parsed.users.findIndex(u => u.userId === userId);
      const userData = {
        username,
        displayName: displayName || username,
        userId,
        jobId: jobId || 'unknown',
        serverId: serverId || 'unknown',
        lastSeen: new Date().toISOString()
      };
      
      if (existingIndex >= 0) {
        parsed.users[existingIndex] = userData;
        console.log('[DEBUG] Updated existing user:', userId);
      } else {
        parsed.users.push(userData);
        console.log('[DEBUG] Added new user:', userId);
      }
      
      parsed.lastUpdated = new Date().toISOString();
      
      // Write updated data
      await fs.writeFile(DATA_FILE, JSON.stringify(parsed, null, 2));
      
      console.log('[DEBUG] Successfully wrote nametag data');
      
      return res.status(200).json({
        success: true,
        message: existingIndex >= 0 ? 'User updated' : 'User added',
        data: userData
      });
    } else {
      return res.status(405).json({
        success: false,
        error: 'Method not allowed'
      });
    }
  } catch (error) {
    console.error('[ERROR] Nametag API error:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
