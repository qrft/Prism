// Vercel Serverless Function for Prism Server List
// Using in-memory storage (for testing - data resets on redeploy)

// In-memory storage for individual players
let playerData = { players: [], lastUpdated: null };

// Auto-remove players inactive for more than 10 seconds
const INACTIVE_TIMEOUT = 10 * 1000; // 10 seconds in milliseconds

function cleanupInactivePlayers() {
  const now = new Date();
  
  playerData.players = playerData.players.filter(player => {
    const lastSeen = new Date(player.lastSeen);
    const inactiveTime = now - lastSeen;
    return inactiveTime < INACTIVE_TIMEOUT;
  });
}

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    // Run cleanup on every request
    cleanupInactivePlayers();

    if (req.method === 'POST') {
      const { jobid, gameName, userId, username, displayName } = req.body;
      
      if (!jobid || !gameName || !userId || !username) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: jobid, gameName, userId, and username'
        });
      }
      
      // Check if player already exists
      const existingIndex = playerData.players.findIndex(p => p.userId === userId);
      const playerInfo = {
        userId: userId,
        username: username,
        displayName: displayName || username,
        jobid: jobid,
        gameName: gameName,
        lastSeen: new Date().toISOString()
      };
      
      if (existingIndex >= 0) {
        playerData.players[existingIndex] = playerInfo;
      } else {
        playerData.players.push(playerInfo);
      }
      
      playerData.lastUpdated = new Date().toISOString();
      
      // Return the list of players
      return res.status(200).json({
        success: true,
        data: playerData.players
      });
    } else if (req.method === 'GET') {
      return res.status(200).json({
        success: true,
        data: playerData.players
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
