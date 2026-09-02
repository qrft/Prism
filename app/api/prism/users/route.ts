import { neon } from '@neondatabase/serverless';

export async function GET(request: Request) {
  try {
    const sql = neon(process.env.DATABASE_URL!);

    // Get all active Prism users (last seen within 1 hour)
    const users = await sql`
      SELECT user_id, username, display_name, server_id, place_id, last_seen
      FROM prism_users
      WHERE last_seen > NOW() - INTERVAL '1 hour'
      ORDER BY last_seen DESC
    `;

    return Response.json({ users });
  } catch (error) {
    console.error('Get users error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
