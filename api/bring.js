// Vercel Serverless Function for Prism Bring System
// Using in-memory storage (for testing - data resets on redeploy)

// In-memory storage for bring requests
let bringData = {
  active: null, // { adminId: number, targetId: number, timestamp: number }
};

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    if (req.method === 'GET') {
      // Return current bring state
      return res.status(200).json({
        success: true,
        data: bringData
      });
    } else if (req.method === 'POST') {
      const { adminId, targetId } = req.body;
      
      if (!adminId || !targetId) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: adminId and targetId'
        });
      }
      
      // Set active bring request
      bringData.active = {
        adminId: adminId,
        targetId: targetId,
        timestamp: Date.now()
      };
      
      return res.status(200).json({
        success: true,
        message: 'Bring request created'
      });
    } else if (req.method === 'DELETE') {
      // Clear active bring request
      bringData.active = null;
      
      return res.status(200).json({
        success: true,
        message: 'Bring request cleared'
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
};
