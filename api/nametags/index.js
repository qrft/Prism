// Nametag API endpoint for Vercel
// Stores nametags and user sessions in memory (for production, use a database like Vercel KV or PostgreSQL)

let nametags = [];
let userSessions = [];

export default function handler(req, res) {
  const { method } = req;
  const { id } = req.query;

  // CORS headers
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');

  if (method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  switch (method) {
    case 'GET':
      // Handle user sessions endpoint
      if (req.query.type === 'sessions') {
        if (id) {
          const session = userSessions.find(s => s.id === id);
          if (!session) {
            return res.status(404).json({ error: 'Session not found' });
          }
          return res.status(200).json(session);
        }
        return res.status(200).json(userSessions);
      }
      
      // Handle nametags
      if (id) {
        const nametag = nametags.find(n => n.id === id);
        if (!nametag) {
          return res.status(404).json({ error: 'Nametag not found' });
        }
        return res.status(200).json(nametag);
      }
      return res.status(200).json(nametags);

    case 'POST':
      // Handle user session registration
      if (req.body.type === 'session') {
        const { userId, userName, gameId, gameName, jobId, scriptRank, scriptName } = req.body;
        
        if (!userId || !gameId) {
          return res.status(400).json({ error: 'userId and gameId are required' });
        }

        const newSession = {
          id: Date.now().toString(),
          userId,
          userName,
          gameId,
          gameName,
          jobId,
          scriptRank,
          scriptName: scriptName || 'Prism',
          startedAt: new Date().toISOString()
        };

        userSessions.push(newSession);
        return res.status(201).json(newSession);
      }
      
      // Handle nametag creation
      const { playerName, tagText, color, enabled } = req.body;
      
      if (!playerName || !tagText) {
        return res.status(400).json({ error: 'playerName and tagText are required' });
      }

      const newNametag = {
        id: Date.now().toString(),
        playerName,
        tagText,
        color: color || '#ffffff',
        enabled: enabled !== false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };

      nametags.push(newNametag);
      return res.status(201).json(newNametag);

    case 'PUT':
      if (!id) {
        return res.status(400).json({ error: 'ID is required for update' });
      }

      const index = nametags.findIndex(n => n.id === id);
      if (index === -1) {
        return res.status(404).json({ error: 'Nametag not found' });
      }

      const { playerName: newPlayerName, tagText: newTagText, color: newColor, enabled: newEnabled } = req.body;
      
      nametags[index] = {
        ...nametags[index],
        playerName: newPlayerName || nametags[index].playerName,
        tagText: newTagText || nametags[index].tagText,
        color: newColor !== undefined ? newColor : nametags[index].color,
        enabled: newEnabled !== undefined ? newEnabled : nametags[index].enabled,
        updatedAt: new Date().toISOString()
      };

      return res.status(200).json(nametags[index]);

    case 'DELETE':
      if (!id) {
        return res.status(400).json({ error: 'ID is required for deletion' });
      }

      const deleteIndex = nametags.findIndex(n => n.id === id);
      if (deleteIndex === -1) {
        return res.status(404).json({ error: 'Nametag not found' });
      }

      nametags.splice(deleteIndex, 1);
      return res.status(200).json({ message: 'Nametag deleted' });

    default:
      res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
      return res.status(405).json({ error: `Method ${method} Not Allowed` });
  }
}
