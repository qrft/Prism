// Vercel Serverless Function for Prism API
// Combines nametags and server tracking into one unified endpoint
// Using Vercel KV (Redis) for shared storage across function instances

const { kv } = require('@vercel/kv');

const PRISM_DATA_KEY = 'prism_users';
const INACTIVE_TIMEOUT = 10 * 1000; // 10 seconds in milliseconds

async function getPrismData() {
  try {
    const data = await kv.get(PRISM_DATA_KEY);
    return data || { users: [], lastUpdated: null };
  } catch (error) {
    console.error('Error getting prism data:', error);
    return { users: [], lastUpdated: null };
  }
}

async function setPrismData(data) {
  try {
    await kv.set(PRISM_DATA_KEY, data, { ex: 30 }); // Auto-expire after 30 seconds
  } catch (error) {
    console.error('Error setting prism data:', error);
  }
}

function cleanupInactiveUsers(users) {
  const now = new Date();
  
  return users.filter(user => {
    const lastSeen = new Date(user.lastSeen);
    const inactiveTime = now - lastSeen;
    return inactiveTime < INACTIVE_TIMEOUT;
  });
}

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    let prismData = await getPrismData();
    
    // Run cleanup on every request
    prismData.users = cleanupInactiveUsers(prismData.users);

    if (req.method === 'GET') {
      return res.status(200).json({
        success: true,
        data: prismData
      });
    } else if (req.method === 'POST') {
      const { username, displayName, userId, jobid, gameName } = req.body;
      
      if (!username || !userId) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: username and userId'
        });
      }
      
      const existingIndex = prismData.users.findIndex(u => u.userId === userId);
      const userData = {
        username,
        displayName: displayName || username,
        userId,
        jobid: jobid || null,
        gameName: gameName || null,
        lastSeen: new Date().toISOString()
      };
      
      if (existingIndex >= 0) {
        prismData.users[existingIndex] = userData;
      } else {
        prismData.users.push(userData);
      }
      
      prismData.lastUpdated = new Date().toISOString();
      
      // Save to KV
      await setPrismData(prismData);
      
      return res.status(200).json({
        success: true,
        message: existingIndex >= 0 ? 'User updated' : 'User added',
        data: userData
      });
    } else if (req.method === 'DELETE') {
      const { userId } = req.body;
      
      if (!userId) {
        return res.status(400).json({
          success: false,
          error: 'Missing userId'
        });
      }
      
      const existingIndex = prismData.users.findIndex(u => u.userId === userId);
      if (existingIndex >= 0) {
        prismData.users.splice(existingIndex, 1);
        prismData.lastUpdated = new Date().toISOString();
        
        // Save to KV
        await setPrismData(prismData);
        
        return res.status(200).json({
          success: true,
          message: 'User removed'
        });
      }
      
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    } else {
      return res.status(405).json({
        success: false,
        error: 'Method not allowed'
      });
    }
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
