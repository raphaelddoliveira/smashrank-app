-- ============================================================
-- 015_reservation_opponent.sql
-- Add opponent declaration fields to court_reservations
-- ============================================================

-- 1. Add opponent columns
ALTER TABLE court_reservations
  ADD COLUMN opponent_id UUID REFERENCES players(id) ON DELETE SET NULL,
  ADD COLUMN opponent_type TEXT CHECK (opponent_type IN ('member', 'guest')),
  ADD COLUMN opponent_name TEXT;

-- 2. Index for opponent lookups
CREATE INDEX idx_reservations_opponent ON court_reservations(opponent_id);

-- 3. Consistency constraint: member requires opponent_id, guest must not have one
ALTER TABLE court_reservations
  ADD CONSTRAINT chk_opponent_consistency CHECK (
    (opponent_type IS NULL) OR
    (opponent_type = 'member' AND opponent_id IS NOT NULL) OR
    (opponent_type = 'guest' AND opponent_id IS NULL)
  );
