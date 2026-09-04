// Vercel Serverless Function for Prism Nametag System
// Using JSONBlob for free persistent storage (no API key needed)

const JSONBLOB_ID = process.env.JSONBLOB_ID || null;

module.exports = async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  try {
    if (req.method === 'GET') {
      // Read nametag data from JSONBlob
      if (!JSONBLOB_ID) {
        return res.status(200).json({
          success: true,
          data: { users: [], lastUpdated: null },
          note: 'Set JSONBLOB_ID environment variable for persistent storage'
        });
      }
      
      const response = await fetch(`https://jsonblob.com/api/jsonBlob/${JSONBLOB_ID}`);
      
      if (!response.ok) {
        // If blob doesn't exist, return empty data
        if (response.status === 404) {
          return res.status(200).json({
            success: true,
            data: { users: [], lastUpdated: null }
          });
        }
        throw new Error(`JSONBlob error: ${response.status}`);
      }
      
      const parsed = await response.json();
      
      console.log('[DEBUG] Reading nametag data:', {
        userCount: parsed.users?.length || 0,
        lastUpdated: parsed.lastUpdated
      });
      
      return res.status(200).json({
        success: true,
        data: parsed
      });
    } else if (req.method === 'POST') {
      console.log('[DEBUG] POST request body:', JSON.stringify(req.body));
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
      
      // Read existing data from JSONBlob
      let parsed = { users: [], lastUpdated: null };
      
      if (JSONBLOB_ID) {
        try {
          const readResponse = await fetch(`https://jsonblob.com/api/jsonBlob/${JSONBLOB_ID}`);
          
          if (readResponse.ok) {
            parsed = await readResponse.json();
          }
        } catch (e) {
          console.log('[DEBUG] No existing data found, starting fresh');
        }
      }
      
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
      
      // Write updated data to JSONBlob
      let blobId = JSONBLOB_ID;
      
      if (blobId) {
        // Update existing blob
        const writeResponse = await fetch(`https://jsonblob.com/api/jsonBlob/${blobId}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(parsed)
        });
        
        if (!writeResponse.ok) {
          throw new Error(`Failed to update JSONBlob: ${writeResponse.status}`);
        }
      } else {
        // Create new blob
        const createResponse = await fetch('https://jsonblob.com/api/jsonBlob', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(parsed)
        });
        
        if (!createResponse.ok) {
          throw new Error(`Failed to create JSONBlob: ${createResponse.status}`);
        }
        
        blobId = createResponse.headers.get('Location')?.split('/').pop();
        console.log('[ DEBUG] Created new JSONBlob with ID:', blobId);
      }
      
      console.log('[DEBUG] Successfully wrote nametag data to JSONBlob');
      
      return res.status(200).json({
        success: true,
        message: existingIndex >= 0 ? 'User updated' : 'User added',
        data: userData,
        blobId: blobId
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
