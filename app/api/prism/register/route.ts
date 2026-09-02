import { neon } from '@neondatabase/serverless';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { userId, username, displayName, serverId, placeId } = body;

    if (!userId || !username || !serverId || !placeId) {
      return Response.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const sql = neon(process.env.DATABASE_URL!);

    // Upsert user (update if exists, insert if new)
    await sql`
      INSERT INTO prism_users (user_id, username, display_name, server_id, place_id, last_seen, opt_in)
      VALUES (${userId}, ${username}, ${displayName}, ${serverId}, ${placeId}, NOW(), true)
      ON CONFLICT (user_id) 
      DO UPDATE SET 
        username = ${username},
        display_name = ${displayName},
        server_id = ${serverId},
        place_id = ${placeId},
        last_seen = NOW(),
        opt_in = true
    `;

    return Response.json({ success: true });
  } catch (error) {
    console.error('Register error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
