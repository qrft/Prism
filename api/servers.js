// Vercel Serverless Function for Prism Server List
// Using in-memory storage (for testing - data resets on redeploy)

// In-memory storage for servers
let serverData = { servers: [], lastUpdated: null };

// Auto-remove servers inactive for more than 30 seconds
const INACTIVE_TIMEOUT = 30 * 1000; // 30 seconds in milliseconds

function cleanupInactiveServers() {
  const now = new Date();
  
  serverData.servers = serverData.servers.filter(server => {
    const lastSeen = new Date(server.lastSeen);
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
    cleanupInactiveServers();

    if (req.method === 'POST') {
      const { jobid, gameName } = req.body;
      
      if (!jobid || !gameName) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: jobid and gameName'
        });
      }
      
      // Check if server already exists
      const existingIndex = serverData.servers.findIndex(s => s.server_id === jobid);
      const serverInfo = {
        server_id: jobid,
        gameName: gameName,
        user_count: 1, // Will be updated based on actual users
        usernames: [], // Will be populated from nametag data
        lastSeen: new Date().toISOString()
      };
      
      if (existingIndex >= 0) {
        serverData.servers[existingIndex] = serverInfo;
      } else {
        serverData.servers.push(serverInfo);
      }
      
      serverData.lastUpdated = new Date().toISOString();
      
      // Return the list of servers
      return res.status(200).json({
        success: true,
        data: serverData.servers
      });
    } else if (req.method === 'GET') {
      return res.status(200).json({
        success: true,
        data: serverData.servers
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
