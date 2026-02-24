-- ============================================================
-- Feature: Admin anular e editar resultado de desafios
-- Novo status annulled + 2 RPCs admin
-- ============================================================

-- Add annulled to challenge_status enum
ALTER TYPE challenge_status ADD VALUE IF NOT EXISTS 'annulled' AFTER 'cancelled';

-- ============================================================
-- RPC: admin_annul_challenge
-- Anula desafio completado, reverte ranking, deleta match
-- ============================================================
CREATE OR REPLACE FUNCTION admin_annul_challenge(
  p_challenge_id UUID,
  p_admin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_rh RECORD;
  v_admin_role TEXT;
  v_player_current_pos INT;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  IF v_challenge.status NOT IN ('completed', 'wo_challenger', 'wo_challenged') THEN
    RAISE EXCEPTION 'Desafio nao esta em status finalizavel: %', v_challenge.status;
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;

  -- Verify admin is club admin
  SELECT role INTO v_admin_role FROM club_members
  WHERE club_id = v_club_id AND player_id = p_admin_id AND status = 'active'
  LIMIT 1;

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem anular desafios';
  END IF;

  -- Reverse ranking changes from ranking_history
  -- Process in reverse order (newest first) to undo correctly
  FOR v_rh IN
    SELECT * FROM ranking_history
    WHERE reference_id = p_challenge_id
      AND club_id = v_club_id
      AND sport_id = v_sport_id
    ORDER BY created_at DESC
  LOOP
    -- Get player's current position
    SELECT ranking_position INTO v_player_current_pos FROM club_members
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;

    IF v_player_current_pos IS NOT NULL AND v_player_current_pos = v_rh.new_position THEN
      -- Player is still at the position the challenge put them in
      -- Move them back to old position
      IF v_rh.old_position < v_rh.new_position THEN
        -- Player went DOWN (e.g., loser: 2 → 3), need to move UP (3 → 2)
        -- Shift players between old and new positions DOWN by 1
        UPDATE club_members
        SET ranking_position = ranking_position + 1
        WHERE club_id = v_club_id AND sport_id = v_sport_id
          AND ranking_position >= v_rh.old_position
          AND ranking_position < v_rh.new_position
          AND player_id != v_rh.player_id;
      ELSE
        -- Player went UP (e.g., winner: 5 → 2), need to move DOWN (2 → 5)
        -- Shift players between old and new positions UP by 1
        UPDATE club_members
        SET ranking_position = ranking_position - 1
        WHERE club_id = v_club_id AND sport_id = v_sport_id
          AND ranking_position > v_rh.new_position
          AND ranking_position <= v_rh.old_position
          AND player_id != v_rh.player_id;
      END IF;

      -- Move the player back
      UPDATE club_members
      SET ranking_position = v_rh.old_position
      WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;
    END IF;
  END LOOP;

  -- Delete ranking_history entries for this challenge
  DELETE FROM ranking_history WHERE reference_id = p_challenge_id;

  -- Delete match record
  DELETE FROM matches WHERE challenge_id = p_challenge_id;

  -- Update challenge status to annulled
  UPDATE challenges
  SET status = 'annulled',
      winner_id = NULL,
      loser_id = NULL,
      result_submitted_by = NULL
  WHERE id = p_challenge_id;

  -- Notify both players
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenger_id,
    'general',
    'Desafio Anulado',
    'O administrador anulou o desafio. O ranking foi revertido.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenged_id,
    'general',
    'Desafio Anulado',
    'O administrador anulou o desafio. O ranking foi revertido.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: admin_edit_challenge_result
-- Admin edita resultado: reverte ranking antigo, aplica novo
-- ============================================================
CREATE OR REPLACE FUNCTION admin_edit_challenge_result(
  p_challenge_id UUID,
  p_admin_id UUID,
  p_new_winner_id UUID,
  p_new_loser_id UUID,
  p_sets JSONB,
  p_winner_sets INT,
  p_loser_sets INT,
  p_super_tiebreak BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_admin_role TEXT;
  v_old_winner_id UUID;
  v_rh RECORD;
  v_player_current_pos INT;
  v_challenger_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  IF v_challenge.status != 'completed' THEN
    RAISE EXCEPTION 'Apenas desafios completados podem ser editados';
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;
  v_old_winner_id := v_challenge.winner_id;
  v_challenger_id := v_challenge.challenger_id;

  -- Verify admin
  SELECT role INTO v_admin_role FROM club_members
  WHERE club_id = v_club_id AND player_id = p_admin_id AND status = 'active'
  LIMIT 1;

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Apenas administradores podem editar resultados';
  END IF;

  -- If winner changed, reverse old ranking and apply new
  IF v_old_winner_id IS DISTINCT FROM p_new_winner_id THEN
    -- 1. Reverse old ranking (same logic as annul)
    FOR v_rh IN
      SELECT * FROM ranking_history
      WHERE reference_id = p_challenge_id
        AND club_id = v_club_id
        AND sport_id = v_sport_id
      ORDER BY created_at DESC
    LOOP
      SELECT ranking_position INTO v_player_current_pos FROM club_members
      WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;

      IF v_player_current_pos IS NOT NULL AND v_player_current_pos = v_rh.new_position THEN
        IF v_rh.old_position < v_rh.new_position THEN
          UPDATE club_members
          SET ranking_position = ranking_position + 1
          WHERE club_id = v_club_id AND sport_id = v_sport_id
            AND ranking_position >= v_rh.old_position
            AND ranking_position < v_rh.new_position
            AND player_id != v_rh.player_id;
        ELSE
          UPDATE club_members
          SET ranking_position = ranking_position - 1
          WHERE club_id = v_club_id AND sport_id = v_sport_id
            AND ranking_position > v_rh.new_position
            AND ranking_position <= v_rh.old_position
            AND player_id != v_rh.player_id;
        END IF;

        UPDATE club_members
        SET ranking_position = v_rh.old_position
        WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_rh.player_id;
      END IF;
    END LOOP;

    -- Delete old ranking_history
    DELETE FROM ranking_history WHERE reference_id = p_challenge_id;

    -- 2. Apply new ranking swap (if new winner is challenger and was below)
    SELECT ranking_position INTO v_winner_pos FROM club_members
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_new_winner_id;
    SELECT ranking_position INTO v_loser_pos FROM club_members
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_new_loser_id;

    IF p_new_winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
      UPDATE club_members SET ranking_position = v_loser_pos
      WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_new_winner_id;
      UPDATE club_members SET ranking_position = v_loser_pos + 1
      WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = p_new_loser_id;

      UPDATE club_members
      SET ranking_position = ranking_position + 1
      WHERE club_id = v_club_id AND sport_id = v_sport_id
        AND ranking_position > v_loser_pos
        AND ranking_position < v_winner_pos
        AND player_id != p_new_winner_id
        AND player_id != p_new_loser_id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
      VALUES (p_new_winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id, v_club_id, v_sport_id);
      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
      VALUES (p_new_loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id, v_club_id, v_sport_id);
    END IF;
  END IF;

  -- Update match record
  UPDATE matches
  SET winner_id = p_new_winner_id,
      loser_id = p_new_loser_id,
      sets = p_sets,
      winner_sets = p_winner_sets,
      loser_sets = p_loser_sets,
      super_tiebreak = p_super_tiebreak
  WHERE challenge_id = p_challenge_id;

  -- Update challenge
  UPDATE challenges
  SET winner_id = p_new_winner_id,
      loser_id = p_new_loser_id
  WHERE id = p_challenge_id;

  -- Notify both players
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenger_id,
    'match_result',
    'Resultado Corrigido',
    'O administrador corrigiu o resultado do desafio.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_challenge.challenged_id,
    'match_result',
    'Resultado Corrigido',
    'O administrador corrigiu o resultado do desafio.',
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
