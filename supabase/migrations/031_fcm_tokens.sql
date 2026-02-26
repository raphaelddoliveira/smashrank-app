-- ============================================================
-- FCM Tokens table for Web Push Notifications
-- Stores Firebase Cloud Messaging tokens per user/device
-- ============================================================

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(player_auth_id, token)
);

-- Index for fast lookups when sending notifications
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_player ON fcm_tokens(player_auth_id);

-- RLS: users can only manage their own tokens
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own tokens"
  ON fcm_tokens FOR INSERT
  WITH CHECK (auth.uid() = player_auth_id);

CREATE POLICY "Users can update their own tokens"
  ON fcm_tokens FOR UPDATE
  USING (auth.uid() = player_auth_id);

CREATE POLICY "Users can delete their own tokens"
  ON fcm_tokens FOR DELETE
  USING (auth.uid() = player_auth_id);

-- Service role can read all tokens (for sending pushes)
CREATE POLICY "Service role can read all tokens"
  ON fcm_tokens FOR SELECT
  USING (auth.uid() = player_auth_id OR auth.role() = 'service_role');
