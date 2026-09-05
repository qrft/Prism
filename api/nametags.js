// Vercel Serverless Function for Prism Nametag System
// Using in-memory storage (for testing - data resets on redeploy)

// In-memory storage (resets on function cold start)
let nametagData = { users: [], lastUpdated: null };

// Auto-remove users inactive for more than 2 minutes
const INACTIVE_TIMEOUT = 2 * 60 * 1000; // 2 minutes in milliseconds

function cleanupInactiveUsers() {
  const now = new Date();
  const beforeCount = nametagData.users.length;
  
  nametagData.users = nametagData.users.filter(user => {
    const lastSeen = new Date(user.lastSeen);
    const inactiveTime = now - lastSeen;
    return inactiveTime < INACTIVE_TIMEOUT;
  });
  
  const removedCount = beforeCount - nametagData.users.length;
  if (removedCount > 0) {
    console.log('[CLEANUP] Removed ' + removedCount + ' inactive users');
  }
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
    // Run cleanup on every request
    cleanupInactiveUsers();

    if (req.method === 'GET') {
      console.log('[DEBUG] Reading nametag data:', {
        userCount: nametagData.users?.length || 0,
        lastUpdated: nametagData.lastUpdated
      });
      
      return res.status(200).json({
        success: true,
        data: nametagData
      });
    } else if (req.method === 'POST') {
      console.log('[DEBUG] POST request body:', JSON.stringify(req.body));
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
      
      // Check if user already exists and update, or add new
      const existingIndex = nametagData.users.findIndex(u => u.userId === userId);
      const userData = {
        username,
        displayName: displayName || username,
        userId,
        jobId: jobId || 'unknown',
        serverId: serverId || 'unknown',
        lastSeen: new Date().toISOString()
      };
      
      if (existingIndex >= 0) {
        nametagData.users[existingIndex] = userData;
        console.log('[DEBUG] Updated existing user:', userId);
      } else {
        nametagData.users.push(userData);
        console.log('[DEBUG] Added new user:', userId);
      }
      
      nametagData.lastUpdated = new Date().toISOString();
      
      console.log('[DEBUG] Successfully stored nametag data in memory');
      
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
      
      const existingIndex = nametagData.users.findIndex(u => u.userId === userId);
      if (existingIndex >= 0) {
        nametagData.users.splice(existingIndex, 1);
        console.log('[DEBUG] Manually removed user:', userId);
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
    console.error('[ERROR] Nametag API error:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
}
