-- ============================================================
-- Fix: Remove club member considering multi-sport system
-- Deactivates all sport entries and recompacts each sport ranking
-- ============================================================

CREATE OR REPLACE FUNCTION remove_club_member(
  p_member_id UUID,
  p_admin_auth_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_member RECORD;
  v_sport_id UUID;
BEGIN
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;

  SELECT * INTO v_member FROM club_members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro nao encontrado';
  END IF;

  -- Verify admin permissions
  IF NOT EXISTS(
    SELECT 1 FROM club_members
    WHERE club_id = v_member.club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas admins do clube podem remover membros';
  END IF;

  -- Prevent removing yourself
  IF v_member.player_id = v_admin_id THEN
    RAISE EXCEPTION 'Voce nao pode remover a si mesmo';
  END IF;

  -- Deactivate ALL entries for this player in this club (all sports)
  UPDATE club_members
  SET status = 'inactive', ranking_position = NULL
  WHERE club_id = v_member.club_id
    AND player_id = v_member.player_id;

  -- Recompact ranking for each sport in this club
  FOR v_sport_id IN
    SELECT DISTINCT sport_id FROM club_members
    WHERE club_id = v_member.club_id AND status = 'active' AND sport_id IS NOT NULL
  LOOP
    WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY ranking_position) as new_pos
      FROM club_members
      WHERE club_id = v_member.club_id
        AND sport_id = v_sport_id
        AND status = 'active'
        AND ranking_position IS NOT NULL
    )
    UPDATE club_members cm
    SET ranking_position = r.new_pos
    FROM ranked r
    WHERE cm.id = r.id;
  END LOOP;

  -- Cancel any pending challenges for this player in this club
  UPDATE challenges
  SET status = 'cancelled', cancelled_at = now()
  WHERE (challenger_id = v_member.player_id OR challenged_id = v_member.player_id)
    AND sport_id IN (SELECT sport_id FROM club_members WHERE club_id = v_member.club_id AND player_id = v_member.player_id)
    AND status IN ('pending', 'dates_proposed', 'scheduled');

  -- Notify the removed player
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_member.player_id,
    'general',
    'Removido do Clube',
    format('Voce foi removido do clube %s.', (SELECT name FROM clubs WHERE id = v_member.club_id)),
    jsonb_build_object('club_id', v_member.club_id),
    v_member.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
