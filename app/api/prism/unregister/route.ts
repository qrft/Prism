import { neon } from '@neondatabase/serverless';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { userId } = body;

    if (!userId) {
      return Response.json({ error: 'Missing userId' }, { status: 400 });
    }

    const sql = neon(process.env.DATABASE_URL!);

    // Set opt_in to false (soft delete)
    await sql`
      UPDATE prism_users
      SET opt_in = false, last_seen = NOW()
      WHERE user_id = ${userId}
    `;

    return Response.json({ success: true });
  } catch (error) {
    console.error('Unregister error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
