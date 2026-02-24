-- ============================================================
-- Feature: Confirmação de resultado pelo oponente
-- Novo status pending_result + coluna result_submitted_by
-- 3 RPCs: submit, confirm, dispute
-- ============================================================

-- Add pending_result to challenge_status enum
ALTER TYPE challenge_status ADD VALUE IF NOT EXISTS 'pending_result' AFTER 'scheduled';

-- Add column to track who submitted the result
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS result_submitted_by UUID REFERENCES players(id);

-- ============================================================
-- RPC: submit_challenge_result
-- Registra resultado provisório (sem alterar ranking)
-- ============================================================
CREATE OR REPLACE FUNCTION submit_challenge_result(
  p_challenge_id UUID,
  p_submitter_id UUID,
  p_winner_id UUID,
  p_loser_id UUID,
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
  v_opponent_id UUID;
  v_submitter_name TEXT;
  v_rule_result_delay BOOLEAN;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;

  -- Allow submission from scheduled or pending_result (resubmission after dispute)
  IF v_challenge.status NOT IN ('scheduled', 'pending_result') THEN
    RAISE EXCEPTION 'Desafio nao esta em status valido: %', v_challenge.status;
  END IF;

  -- Verify submitter is a participant
  IF p_submitter_id != v_challenge.challenger_id AND p_submitter_id != v_challenge.challenged_id THEN
    RAISE EXCEPTION 'Apenas participantes podem registrar resultado';
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;

  -- Check result delay rule (40 min after scheduled time)
  SELECT rule_result_delay_enabled INTO v_rule_result_delay
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_result_delay := COALESCE(v_rule_result_delay, true);

  IF v_rule_result_delay AND v_challenge.chosen_date IS NOT NULL
     AND now() < v_challenge.chosen_date + INTERVAL '40 minutes' THEN
    RAISE EXCEPTION 'Resultado so pode ser registrado 40 minutos apos o horario agendado';
  END IF;

  -- If resubmitting (pending_result), delete previous match
  IF v_challenge.status = 'pending_result' THEN
    DELETE FROM matches WHERE challenge_id = p_challenge_id;
  END IF;

  -- Insert match record (provisional)
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak, club_id, sport_id)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak, v_club_id, v_sport_id);

  -- Update challenge to pending_result
  UPDATE challenges
  SET status = 'pending_result',
      winner_id = p_winner_id,
      loser_id = p_loser_id,
      result_submitted_by = p_submitter_id
  WHERE id = p_challenge_id;

  -- Determine opponent
  IF p_submitter_id = v_challenge.challenger_id THEN
    v_opponent_id := v_challenge.challenged_id;
  ELSE
    v_opponent_id := v_challenge.challenger_id;
  END IF;

  -- Get submitter name
  SELECT full_name INTO v_submitter_name FROM players WHERE id = p_submitter_id;

  -- Notify opponent to confirm
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_opponent_id,
    'match_result',
    'Confirme o resultado',
    format('%s registrou o resultado do desafio. Confirme ou conteste.', v_submitter_name),
    jsonb_build_object('challenge_id', p_challenge_id),
    v_club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: confirm_challenge_result
-- Confirma resultado e aplica ranking swap + cooldowns
-- ============================================================
CREATE OR REPLACE FUNCTION confirm_challenge_result(
  p_challenge_id UUID,
  p_confirmer_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_match RECORD;
  v_club_id UUID;
  v_sport_id UUID;
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_rule_cooldown BOOLEAN;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;
  IF v_challenge.status != 'pending_result' THEN
    RAISE EXCEPTION 'Desafio nao esta aguardando confirmacao';
  END IF;

  -- Confirmer must NOT be who submitted
  IF p_confirmer_id = v_challenge.result_submitted_by THEN
    RAISE EXCEPTION 'Voce nao pode confirmar seu proprio resultado';
  END IF;

  -- Verify confirmer is a participant
  IF p_confirmer_id != v_challenge.challenger_id AND p_confirmer_id != v_challenge.challenged_id THEN
    RAISE EXCEPTION 'Apenas participantes podem confirmar resultado';
  END IF;

  -- Get match data
  SELECT * INTO v_match FROM matches WHERE challenge_id = p_challenge_id ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match nao encontrado para este desafio';
  END IF;

  v_club_id := v_challenge.club_id;
  v_sport_id := v_challenge.sport_id;
  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;

  -- Fetch cooldown rule
  SELECT rule_cooldown_enabled INTO v_rule_cooldown
  FROM club_sports WHERE club_id = v_club_id AND sport_id = v_sport_id AND is_active = true;
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  -- Get current positions
  SELECT ranking_position INTO v_winner_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_match.winner_id;
  SELECT ranking_position INTO v_loser_pos FROM club_members
  WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_match.loser_id;

  -- Ranking swap: only if challenger won AND was below
  IF v_match.winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
    UPDATE club_members SET ranking_position = v_loser_pos
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_match.winner_id;
    UPDATE club_members SET ranking_position = v_loser_pos + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_match.loser_id;

    UPDATE club_members
    SET ranking_position = ranking_position + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id
      AND ranking_position > v_loser_pos
      AND ranking_position < v_winner_pos
      AND player_id != v_match.winner_id
      AND player_id != v_match.loser_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_match.winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id, v_club_id, v_sport_id);
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_match.loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id, v_club_id, v_sport_id);

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_match.winner_id, 'ranking_change', 'Ranking Atualizado!',
      format('Voce subiu para a posicao #%s (era #%s).', v_loser_pos, v_winner_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_winner_pos, 'new_position', v_loser_pos),
      v_club_id
    );
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_match.loser_id, 'ranking_change', 'Ranking Atualizado',
      format('Voce desceu para a posicao #%s (era #%s).', v_loser_pos + 1, v_loser_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_loser_pos, 'new_position', v_loser_pos + 1),
      v_club_id
    );
  END IF;

  -- Update challenge to completed
  UPDATE challenges
  SET status = 'completed',
      completed_at = now(),
      result_submitted_by = NULL
  WHERE id = p_challenge_id;

  -- Set cooldowns
  IF v_rule_cooldown THEN
    UPDATE club_members
    SET challenger_cooldown_until = now() + INTERVAL '48 hours',
        last_challenge_date = now(),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;

    UPDATE club_members
    SET challenged_protection_until = now() + INTERVAL '24 hours'
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenged_id;
  ELSE
    UPDATE club_members
    SET last_challenge_date = now(),
        challenges_this_month = challenges_this_month + 1
    WHERE club_id = v_club_id AND sport_id = v_sport_id AND player_id = v_challenger_id;
  END IF;

  -- Send match_result notifications
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (v_match.winner_id, 'match_result', 'Resultado Confirmado', 'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (v_match.loser_id, 'match_result', 'Resultado Confirmado', 'O resultado do seu desafio foi confirmado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id), v_club_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- RPC: dispute_challenge_result
-- Contesta resultado, volta pra scheduled
-- ============================================================
CREATE OR REPLACE FUNCTION dispute_challenge_result(
  p_challenge_id UUID,
  p_disputer_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_challenge RECORD;
  v_submitter_id UUID;
  v_disputer_name TEXT;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado';
  END IF;
  IF v_challenge.status != 'pending_result' THEN
    RAISE EXCEPTION 'Desafio nao esta aguardando confirmacao';
  END IF;

  -- Disputer must NOT be who submitted
  IF p_disputer_id = v_challenge.result_submitted_by THEN
    RAISE EXCEPTION 'Voce nao pode contestar seu proprio resultado';
  END IF;

  -- Verify disputer is a participant
  IF p_disputer_id != v_challenge.challenger_id AND p_disputer_id != v_challenge.challenged_id THEN
    RAISE EXCEPTION 'Apenas participantes podem contestar resultado';
  END IF;

  v_submitter_id := v_challenge.result_submitted_by;

  -- Delete the provisional match
  DELETE FROM matches WHERE challenge_id = p_challenge_id;

  -- Reset challenge back to scheduled
  UPDATE challenges
  SET status = 'scheduled',
      winner_id = NULL,
      loser_id = NULL,
      result_submitted_by = NULL
  WHERE id = p_challenge_id;

  -- Get disputer name
  SELECT full_name INTO v_disputer_name FROM players WHERE id = p_disputer_id;

  -- Notify submitter
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_submitter_id,
    'match_result',
    'Resultado Contestado',
    format('%s contestou o resultado. Corrija e registre novamente.', v_disputer_name),
    jsonb_build_object('challenge_id', p_challenge_id),
    v_challenge.club_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
