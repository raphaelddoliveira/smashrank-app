-- ============================================================
-- SmashRank - Database Functions
-- ============================================================

-- ============================================================
-- FUNCTION: swap_ranking_after_challenge
-- When challenger wins: takes loser's position, loser drops 1
-- When challenged wins: no position change
-- ============================================================
CREATE OR REPLACE FUNCTION swap_ranking_after_challenge(
  p_challenge_id UUID,
  p_winner_id UUID,
  p_loser_id UUID,
  p_sets JSONB,
  p_winner_sets INT,
  p_loser_sets INT,
  p_super_tiebreak BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_challenge RECORD;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found: %', p_challenge_id;
  END IF;
  IF v_challenge.status NOT IN ('scheduled', 'wo_challenged') THEN
    RAISE EXCEPTION 'Challenge is not in valid status: %', v_challenge.status;
  END IF;

  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;

  SELECT ranking_position INTO v_winner_pos FROM players WHERE id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM players WHERE id = p_loser_id;

  -- Record match
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak);

  -- Only swap if challenger won AND challenger was below (higher number)
  IF p_winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
    UPDATE players SET ranking_position = v_loser_pos WHERE id = p_winner_id;
    UPDATE players SET ranking_position = v_loser_pos + 1 WHERE id = p_loser_id;

    -- Push everyone between old positions down by 1
    UPDATE players
    SET ranking_position = ranking_position + 1
    WHERE ranking_position > v_loser_pos
      AND ranking_position < v_winner_pos
      AND id != p_winner_id
      AND id != p_loser_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
    VALUES (p_winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id);
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
    VALUES (p_loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id);

    -- Notification: ranking_change for winner
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      p_winner_id,
      'ranking_change',
      'Ranking Atualizado!',
      format('Voce subiu para a posicao #%s (era #%s).', v_loser_pos, v_winner_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_winner_pos, 'new_position', v_loser_pos)
    );

    -- Notification: ranking_change for loser
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      p_loser_id,
      'ranking_change',
      'Ranking Atualizado',
      format('Voce desceu para a posicao #%s (era #%s).', v_loser_pos + 1, v_loser_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_loser_pos, 'new_position', v_loser_pos + 1)
    );
  END IF;

  -- Update challenge status
  UPDATE challenges
  SET status = 'completed',
      winner_id = p_winner_id,
      loser_id = p_loser_id,
      completed_at = now()
  WHERE id = p_challenge_id;

  -- Set cooldowns
  UPDATE players
  SET challenger_cooldown_until = now() + INTERVAL '48 hours',
      last_challenge_date = now(),
      challenges_this_month = challenges_this_month + 1
  WHERE id = v_challenger_id;

  UPDATE players
  SET challenged_protection_until = now() + INTERVAL '24 hours'
  WHERE id = v_challenged_id;

  -- Notification: match_result for winner
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_winner_id,
    'match_result',
    'Resultado Registrado',
    'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id)
  );

  -- Notification: match_result for loser
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_loser_id,
    'match_result',
    'Resultado Registrado',
    'O resultado do seu desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: activate_ambulance
-- -3 positions immediately, 10 days protection
-- ============================================================
CREATE OR REPLACE FUNCTION activate_ambulance(
  p_player_id UUID,
  p_reason TEXT
)
RETURNS UUID AS $$
DECLARE
  v_current_pos INT;
  v_new_pos INT;
  v_max_pos INT;
  v_ambulance_id UUID;
BEGIN
  SELECT ranking_position INTO v_current_pos FROM players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found: %', p_player_id;
  END IF;

  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';
  v_new_pos := LEAST(v_current_pos + 3, v_max_pos);

  -- Shift players between old+1 and new up by 1
  UPDATE players
  SET ranking_position = ranking_position - 1
  WHERE ranking_position > v_current_pos
    AND ranking_position <= v_new_pos
    AND id != p_player_id;

  UPDATE players
  SET ranking_position = v_new_pos,
      status = 'ambulance',
      ambulance_active = TRUE,
      ambulance_started_at = now(),
      ambulance_protection_until = now() + INTERVAL '10 days',
      must_be_challenged_first = TRUE
  WHERE id = p_player_id;

  INSERT INTO ambulances (player_id, reason, position_at_activation, initial_penalty_applied, protection_ends_at)
  VALUES (p_player_id, p_reason, v_current_pos, TRUE, now() + INTERVAL '10 days')
  RETURNING id INTO v_ambulance_id;

  INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
  VALUES (p_player_id, v_current_pos, v_new_pos, 'ambulance_penalty', v_ambulance_id);

  -- Notification: ambulance_activated
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_player_id,
    'ambulance_activated',
    'Ambulancia Ativada',
    format('Ambulancia ativada. Voce foi para a posicao #%s (era #%s). Protecao de 10 dias ativa.', v_new_pos, v_current_pos),
    jsonb_build_object('ambulance_id', v_ambulance_id, 'reason', p_reason, 'old_position', v_current_pos, 'new_position', v_new_pos)
  );

  RETURN v_ambulance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: deactivate_ambulance
-- ============================================================
CREATE OR REPLACE FUNCTION deactivate_ambulance(p_player_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE ambulances
  SET is_active = FALSE, deactivated_at = now()
  WHERE player_id = p_player_id AND is_active = TRUE;

  UPDATE players
  SET status = 'active',
      ambulance_active = FALSE,
      ambulance_started_at = NULL,
      ambulance_protection_until = NULL
  WHERE id = p_player_id;

  -- Notification: ambulance_expired
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_player_id,
    'ambulance_expired',
    'Ambulancia Desativada',
    'Sua ambulancia foi desativada. Voce esta de volta ao ranking ativo.',
    jsonb_build_object()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: apply_ambulance_daily_penalties
-- Called by cron: -1 position per day after protection ends
-- ============================================================
CREATE OR REPLACE FUNCTION apply_ambulance_daily_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_ambulance RECORD;
  v_current_pos INT;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_ambulance IN
    SELECT a.*, p.ranking_position
    FROM ambulances a
    JOIN players p ON p.id = a.player_id
    WHERE a.is_active = TRUE
      AND a.protection_ends_at < now()
      AND (a.last_daily_penalty_at IS NULL
           OR a.last_daily_penalty_at < now() - INTERVAL '1 day')
  LOOP
    v_current_pos := v_ambulance.ranking_position;
    IF v_current_pos < v_max_pos THEN
      UPDATE players
      SET ranking_position = ranking_position - 1
      WHERE ranking_position = v_current_pos + 1
        AND id != v_ambulance.player_id;

      UPDATE players
      SET ranking_position = v_current_pos + 1
      WHERE id = v_ambulance.player_id;

      UPDATE ambulances
      SET daily_penalties_applied = daily_penalties_applied + 1,
          last_daily_penalty_at = now()
      WHERE id = v_ambulance.id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
      VALUES (v_ambulance.player_id, v_current_pos, v_current_pos + 1, 'ambulance_daily_penalty', v_ambulance.id);

      -- Notification: ranking_change for ambulance daily penalty
      INSERT INTO notifications (player_id, type, title, body, data)
      VALUES (
        v_ambulance.player_id,
        'ranking_change',
        'Penalizacao Diaria - Ambulancia',
        format('Voce perdeu 1 posicao por ambulancia ativa. Agora: #%s.', v_current_pos + 1),
        jsonb_build_object('old_position', v_current_pos, 'new_position', v_current_pos + 1)
      );

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: apply_overdue_penalties
-- Players 15+ days overdue lose 10 positions
-- ============================================================
CREATE OR REPLACE FUNCTION apply_overdue_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_player RECORD;
  v_new_pos INT;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_player IN
    SELECT p.*
    FROM players p
    JOIN monthly_fees mf ON mf.player_id = p.id
    WHERE mf.status = 'overdue'
      AND mf.due_date + INTERVAL '15 days' <= CURRENT_DATE
      AND p.status = 'active'
      AND p.fee_status != 'overdue'
  LOOP
    v_new_pos := LEAST(v_player.ranking_position + 10, v_max_pos);

    UPDATE players
    SET ranking_position = ranking_position - 1
    WHERE ranking_position > v_player.ranking_position
      AND ranking_position <= v_new_pos
      AND id != v_player.id;

    UPDATE players
    SET ranking_position = v_new_pos,
        fee_status = 'overdue',
        fee_overdue_since = CURRENT_DATE
    WHERE id = v_player.id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason)
    VALUES (v_player.id, v_player.ranking_position, v_new_pos, 'overdue_penalty');

    -- Notification: payment_overdue
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_player.id,
      'payment_overdue',
      'Penalizacao por Inadimplencia',
      format('Voce perdeu %s posicoes por atraso na mensalidade (15+ dias). Regularize para evitar mais penalizacoes.', v_new_pos - v_player.ranking_position),
      jsonb_build_object('old_position', v_player.ranking_position, 'new_position', v_new_pos)
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: apply_monthly_inactivity_penalties
-- No challenge in a month = -1 position
-- ============================================================
CREATE OR REPLACE FUNCTION apply_monthly_inactivity_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_player RECORD;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_player IN
    SELECT * FROM players
    WHERE status = 'active'
      AND challenges_this_month = 0
      AND ranking_position < v_max_pos
  LOOP
    UPDATE players
    SET ranking_position = ranking_position - 1
    WHERE ranking_position = v_player.ranking_position + 1
      AND id != v_player.id;

    UPDATE players
    SET ranking_position = v_player.ranking_position + 1
    WHERE id = v_player.id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason)
    VALUES (v_player.id, v_player.ranking_position, v_player.ranking_position + 1, 'monthly_inactivity');

    -- Notification: ranking_change for monthly inactivity
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_player.id,
      'ranking_change',
      'Penalizacao por Inatividade',
      format('Voce perdeu 1 posicao por nao ter jogado nenhum desafio este mes. Agora: #%s.', v_player.ranking_position + 1),
      jsonb_build_object('old_position', v_player.ranking_position, 'new_position', v_player.ranking_position + 1)
    );

    v_count := v_count + 1;
  END LOOP;

  UPDATE players SET challenges_this_month = 0 WHERE status != 'inactive';

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: validate_challenge_creation
-- Enforces all business rules before allowing a challenge
-- ============================================================
CREATE OR REPLACE FUNCTION validate_challenge_creation(
  p_challenger_id UUID,
  p_challenged_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_challenger RECORD;
  v_challenged RECORD;
  v_active_challenge_count INT;
BEGIN
  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  IF v_challenger.status != 'active' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador nao esta ativo');
  END IF;
  IF v_challenged.status NOT IN ('active') THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta disponivel');
  END IF;

  IF v_challenger.fee_status = 'overdue' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Mensalidade em atraso. Regularize para desafiar.');
  END IF;

  IF v_challenger.must_be_challenged_first THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Voce deve ser desafiado primeiro apos retornar da ambulancia');
  END IF;

  IF v_challenger.ranking_position - v_challenged.ranking_position > 2 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;
  IF v_challenged.ranking_position >= v_challenger.ranking_position THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'So pode desafiar jogadores acima no ranking');
  END IF;

  IF v_challenger.challenger_cooldown_until IS NOT NULL
     AND v_challenger.challenger_cooldown_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      format('Cooldown ativo ate %s', v_challenger.challenger_cooldown_until));
  END IF;

  IF v_challenged.challenged_protection_until IS NOT NULL
     AND v_challenged.challenged_protection_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Este jogador esta protegido temporariamente');
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Um dos jogadores ja possui um desafio ativo');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: create_challenge
-- ============================================================
CREATE OR REPLACE FUNCTION create_challenge(
  p_challenger_auth_id UUID,
  p_challenged_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_challenger_id UUID;
  v_validation JSONB;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  v_validation := validate_challenge_creation(v_challenger_id, p_challenged_id);
  IF NOT (v_validation->>'valid')::BOOLEAN THEN
    RAISE EXCEPTION '%', v_validation->>'error';
  END IF;

  SELECT ranking_position INTO v_challenger_pos FROM players WHERE id = v_challenger_id;
  SELECT ranking_position INTO v_challenged_pos FROM players WHERE id = p_challenged_id;

  INSERT INTO challenges (
    challenger_id, challenged_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    v_challenger_id, p_challenged_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_challenged_id,
    'challenge_received',
    'Novo Desafio!',
    format('Voce foi desafiado pelo jogador da posicao #%s. Responda em 48h.', v_challenger_pos),
    jsonb_build_object('challenge_id', v_challenge_id)
  );

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: expire_pending_challenges
-- Auto-expire challenges without response after 48h
-- ============================================================
CREATE OR REPLACE FUNCTION expire_pending_challenges()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_challenge RECORD;
BEGIN
  FOR v_challenge IN
    SELECT * FROM challenges
    WHERE status = 'pending'
      AND response_deadline < now()
  LOOP
    -- Set to 'scheduled' temporarily so swap_ranking_after_challenge works
    UPDATE challenges
    SET status = 'scheduled'
    WHERE id = v_challenge.id;

    -- Perform the ranking swap (this sets status to 'completed' + sends match_result notifications)
    PERFORM swap_ranking_after_challenge(
      v_challenge.id,
      v_challenge.challenger_id,
      v_challenge.challenged_id,
      '[]'::JSONB, 0, 0, FALSE
    );

    -- Override to wo_challenged status
    UPDATE challenges
    SET status = 'wo_challenged',
        wo_player_id = v_challenge.challenged_id
    WHERE id = v_challenge.id;

    -- Notification: wo_warning for challenged player (who didn't respond)
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_challenge.challenged_id,
      'wo_warning',
      'WO - Desafio Expirado',
      'Voce nao respondeu ao desafio em 48h e perdeu por WO.',
      jsonb_build_object('challenge_id', v_challenge.id)
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
