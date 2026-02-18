-- ============================================================
-- SmashRank - Migration 011: Sports is_active toggle
-- Allows platform admin to enable/disable sports globally
-- ============================================================

ALTER TABLE sports ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- Allow platform admins to update sports (toggle is_active, etc)
CREATE POLICY sports_update ON sports
  FOR UPDATE TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
