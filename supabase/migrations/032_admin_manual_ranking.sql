-- ============================================================
-- Feature: Admin Manual Ranking Reorder
-- Admin pode reordenar o ranking manualmente (ex: clube novo
-- que já possui ranking definido)
-- ============================================================

-- Drop old JSONB version if exists (signature changed to JSON)
DROP FUNCTION IF EXISTS admin_reorder_ranking(UUID, UUID, UUID, JSONB);

CREATE OR REPLACE FUNCTION admin_reorder_ranking(
  p_admin_auth_id UUID,
  p_club_id UUID,
  p_sport_id UUID,
  p_ranking_order JSON  -- Array of {member_id: UUID, new_position: INT}
)
RETURNS VOID AS $$
DECLARE
  v_admin_id UUID;
  v_admin_member RECORD;
  v_ranked_count INT;
  v_order_count INT;
  v_item RECORD;
  v_old_position INT;
  v_max_position INT;
  v_positions_valid BOOLEAN;
  v_ranking JSONB := p_ranking_order::JSONB;
BEGIN
  -- ==================== VALIDATE ADMIN ====================
  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  SELECT * INTO v_admin_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e admin deste clube';
  END IF;

  -- ==================== VALIDATE INPUT ====================
  -- Count currently ranked members
  SELECT COUNT(*) INTO v_ranked_count
  FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status = 'active' AND ranking_position IS NOT NULL;

  -- Count items in the input array
  SELECT jsonb_array_length(v_ranking) INTO v_order_count;

  IF v_ranked_count != v_order_count THEN
    RAISE EXCEPTION 'A lista deve conter todos os % jogadores rankeados (recebido %)',
      v_ranked_count, v_order_count;
  END IF;

  -- Validate all member_ids exist and belong to this club+sport+ranked
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_ranking) AS item
    WHERE NOT EXISTS (
      SELECT 1 FROM club_members
      WHERE id = (item->>'member_id')::UUID
        AND club_id = p_club_id
        AND sport_id = p_sport_id
        AND status = 'active'
        AND ranking_position IS NOT NULL
    )
  ) THEN
    RAISE EXCEPTION 'Um ou mais member_ids nao pertencem ao ranking deste clube/esporte';
  END IF;

  -- Validate positions are contiguous 1..N with no gaps or duplicates
  SELECT
    COUNT(DISTINCT (item->>'new_position')::INT) = v_order_count
    AND MIN((item->>'new_position')::INT) = 1
    AND MAX((item->>'new_position')::INT) = v_order_count
  INTO v_positions_valid
  FROM jsonb_array_elements(v_ranking) AS item;

  IF NOT v_positions_valid THEN
    RAISE EXCEPTION 'Posicoes devem ser sequenciais de 1 a %', v_order_count;
  END IF;

  -- ==================== RECORD HISTORY ====================
  INSERT INTO ranking_history (player_id, old_position, new_position, reason, club_id, sport_id)
  SELECT
    cm.player_id,
    cm.ranking_position,
    (item->>'new_position')::INT,
    'admin_adjustment',
    p_club_id,
    p_sport_id
  FROM jsonb_array_elements(v_ranking) AS item
  JOIN club_members cm ON cm.id = (item->>'member_id')::UUID
  WHERE cm.ranking_position != (item->>'new_position')::INT;

  -- ==================== APPLY NEW POSITIONS ====================
  -- Set all to negative first to avoid unique constraint conflicts
  UPDATE club_members
  SET ranking_position = -(ranking_position)
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status = 'active' AND ranking_position IS NOT NULL;

  -- Apply new positions from the JSONB array
  UPDATE club_members cm
  SET ranking_position = (item->>'new_position')::INT
  FROM jsonb_array_elements(v_ranking) AS item
  WHERE cm.id = (item->>'member_id')::UUID;

  -- ==================== NOTIFY AFFECTED PLAYERS ====================
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  SELECT
    cm.player_id,
    'general',
    'Ranking Ajustado',
    format('O administrador ajustou o ranking. Sua nova posicao e #%s.', (item->>'new_position')::INT),
    jsonb_build_object(
      'club_id', p_club_id,
      'sport_id', p_sport_id,
      'old_position', rh.old_position,
      'new_position', rh.new_position
    ),
    p_club_id
  FROM jsonb_array_elements(v_ranking) AS item
  JOIN club_members cm ON cm.id = (item->>'member_id')::UUID
  JOIN ranking_history rh ON rh.player_id = cm.player_id
    AND rh.club_id = p_club_id
    AND rh.sport_id = p_sport_id
    AND rh.reason = 'admin_adjustment'
    AND rh.new_position = (item->>'new_position')::INT
    AND rh.old_position != rh.new_position
    AND rh.created_at >= now() - interval '5 seconds';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
