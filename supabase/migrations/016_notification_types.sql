-- ============================================================
-- 016_notification_types.sql
-- Add missing notification_type enum values for challenge flow
-- ============================================================

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'court_selected';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'challenge_accepted';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'challenge_declined';
