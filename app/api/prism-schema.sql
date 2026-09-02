-- Prism Users Table
CREATE TABLE IF NOT EXISTS prism_users (
    user_id BIGINT PRIMARY KEY,
    username VARCHAR(50),
    display_name VARCHAR(50),
    server_id VARCHAR(50),
    place_id BIGINT,
    last_seen TIMESTAMP DEFAULT NOW(),
    opt_in BOOLEAN DEFAULT true
);

-- Index for faster server queries
CREATE INDEX IF NOT EXISTS idx_server_id ON prism_users(server_id);
CREATE INDEX IF NOT EXISTS idx_last_seen ON prism_users(last_seen);

-- Function to clean up old entries (older than 1 hour)
CREATE OR REPLACE FUNCTION cleanup_old_users()
RETURNS void AS $$
BEGIN
    DELETE FROM prism_users WHERE last_seen < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;
