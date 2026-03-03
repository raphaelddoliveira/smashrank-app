-- ============================================================
-- SmashRank - Row Level Security Policies
-- ============================================================

-- Helper functions
CREATE OR REPLACE FUNCTION get_player_role()
RETURNS player_role AS $$
  SELECT role FROM players WHERE auth_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM players WHERE auth_id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_player_id()
RETURNS UUID AS $$
  SELECT id FROM players WHERE auth_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- PLAYERS
-- ============================================================
ALTER TABLE players ENABLE ROW LEVEL SECURITY;

CREATE POLICY players_select ON players
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY players_insert ON players
  FOR INSERT TO authenticated
  WITH CHECK (auth_id = auth.uid() OR is_admin());

CREATE POLICY players_update_own ON players
  FOR UPDATE TO authenticated
  USING (auth_id = auth.uid());

CREATE POLICY players_admin_update ON players
  FOR UPDATE TO authenticated
  USING (is_admin());

-- ============================================================
-- RANKING_HISTORY
-- ============================================================
ALTER TABLE ranking_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY ranking_history_select ON ranking_history
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY ranking_history_admin_insert ON ranking_history
  FOR INSERT TO authenticated
  WITH CHECK (is_admin());

-- ============================================================
-- CHALLENGES
-- ============================================================
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenges_select ON challenges
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY challenges_insert ON challenges
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() OR challenger_id = get_player_id());

CREATE POLICY challenges_update ON challenges
  FOR UPDATE TO authenticated
  USING (
    challenger_id = get_player_id()
    OR challenged_id = get_player_id()
    OR is_admin()
  );

-- ============================================================
-- MATCHES
-- ============================================================
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY matches_select ON matches
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY matches_insert ON matches
  FOR INSERT TO authenticated
  WITH CHECK (
    winner_id = get_player_id()
    OR loser_id = get_player_id()
    OR is_admin()
  );

-- ============================================================
-- AMBULANCES
-- ============================================================
ALTER TABLE ambulances ENABLE ROW LEVEL SECURITY;

CREATE POLICY ambulances_select ON ambulances
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY ambulances_insert ON ambulances
  FOR INSERT TO authenticated
  WITH CHECK (is_admin());

CREATE POLICY ambulances_update ON ambulances
  FOR UPDATE TO authenticated
  USING (is_admin());

-- ============================================================
-- COURTS
-- ============================================================
ALTER TABLE courts ENABLE ROW LEVEL SECURITY;

CREATE POLICY courts_select ON courts
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY courts_admin ON courts
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================
-- COURT_SLOTS
-- ============================================================
ALTER TABLE court_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY court_slots_select ON court_slots
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY court_slots_admin ON court_slots
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================
-- COURT_RESERVATIONS
-- ============================================================
ALTER TABLE court_reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY reservations_select ON court_reservations
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY reservations_insert ON court_reservations
  FOR INSERT TO authenticated
  WITH CHECK (reserved_by = get_player_id() OR is_admin());

CREATE POLICY reservations_update ON court_reservations
  FOR UPDATE TO authenticated
  USING (reserved_by = get_player_id() OR is_admin());

CREATE POLICY reservations_delete ON court_reservations
  FOR DELETE TO authenticated
  USING (reserved_by = get_player_id() OR is_admin());

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select ON notifications
  FOR SELECT TO authenticated
  USING (player_id = get_player_id());

CREATE POLICY notifications_update ON notifications
  FOR UPDATE TO authenticated
  USING (player_id = get_player_id())
  WITH CHECK (player_id = get_player_id());

CREATE POLICY notifications_insert ON notifications
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR player_id != get_player_id()
  );

-- ============================================================
-- MONTHLY_FEES
-- ============================================================
ALTER TABLE monthly_fees ENABLE ROW LEVEL SECURITY;

CREATE POLICY fees_select ON monthly_fees
  FOR SELECT TO authenticated
  USING (player_id = get_player_id() OR is_admin());

CREATE POLICY fees_admin ON monthly_fees
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- ============================================================
-- WHATSAPP_LOGS
-- ============================================================
ALTER TABLE whatsapp_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_admin ON whatsapp_logs
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());
