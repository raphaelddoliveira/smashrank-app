-- ============================================================
-- 020: Add candidate_id to court_reservations
-- ============================================================
-- Allows players to apply to play in open reservations.
-- The reservation owner can accept or reject candidates.
-- ============================================================

ALTER TABLE court_reservations
  ADD COLUMN candidate_id UUID REFERENCES players(id) ON DELETE SET NULL;
