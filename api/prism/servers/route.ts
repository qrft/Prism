import { neon } from '@neondatabase/serverless';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const excludeServerId = searchParams.get('exclude');

    const sql = neon(process.env.DATABASE_URL!);

    // Get servers with Prism users, grouped by server
    let query = sql`
      SELECT server_id, place_id, COUNT(*) as user_count, 
             array_agg(username) as usernames,
             MAX(last_seen) as last_activity
      FROM prism_users
      WHERE last_seen > NOW() - INTERVAL '1 hour'
      AND opt_in = true
    `;

    if (excludeServerId) {
      query = sql`
        SELECT server_id, place_id, COUNT(*) as user_count, 
               array_agg(username) as usernames,
               MAX(last_seen) as last_activity
        FROM prism_users
        WHERE last_seen > NOW() - INTERVAL '1 hour'
        AND opt_in = true
        AND server_id != ${excludeServerId}
      `;
    }

    const servers = await sql`
      ${query}
      GROUP BY server_id, place_id
      ORDER BY user_count DESC, last_activity DESC
    `;

    return Response.json({ servers });
  } catch (error) {
    console.error('Get servers error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
