-- ============================================================
-- Feature: Ranking Opt-In/Out (Participação no Ranking)
-- Jogador pode sair/entrar no ranking. Ranking recompacta.
-- Desafios ativos são cancelados ao sair.
-- ============================================================

-- Nova coluna para controlar opt-in/out
ALTER TABLE club_members
  ADD COLUMN IF NOT EXISTS ranking_opt_in BOOLEAN NOT NULL DEFAULT TRUE;

-- Allow NULL in new_position for opt-out (was NOT NULL)
ALTER TABLE ranking_history ALTER COLUMN new_position DROP NOT NULL;

-- ============================================================
-- RPC: toggle_ranking_participation
-- Ativa/desativa participação no ranking
-- ============================================================
CREATE OR REPLACE FUNCTION toggle_ranking_participation(
  p_auth_id UUID,
  p_club_id UUID,
  p_sport_id UUID,
  p_opt_in BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_player_id UUID;
  v_member RECORD;
  v_old_position INT;
  v_new_position INT;
  v_challenge RECORD;
BEGIN
  -- Get player_id from auth_id
  SELECT id INTO v_player_id FROM players WHERE auth_id = p_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado';
  END IF;

  -- Get membership
  SELECT * INTO v_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_player_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste esporte neste clube';
  END IF;

  -- ==================== OPT-OUT ====================
  IF p_opt_in = FALSE THEN
    IF v_member.ranking_position IS NULL THEN
      RAISE EXCEPTION 'Voce ja esta fora do ranking';
    END IF;

    v_old_position := v_member.ranking_position;

    -- Cancel active challenges for this player in this club+sport
    FOR v_challenge IN
      SELECT id, challenger_id, challenged_id FROM challenges
      WHERE club_id = p_club_id AND sport_id = p_sport_id
        AND status IN ('pending', 'dates_proposed', 'scheduled', 'pending_result')
        AND (challenger_id = v_player_id OR challenged_id = v_player_id)
    LOOP
      -- Cancel linked reservations
      UPDATE reservations
      SET status = 'cancelled'
      WHERE challenge_id = v_challenge.id AND status = 'active';

      -- Cancel the challenge
      UPDATE challenges
      SET status = 'cancelled'
      WHERE id = v_challenge.id;

      -- Notify the opponent
      INSERT INTO notifications (player_id, type, title, body, data, club_id)
      VALUES (
        CASE WHEN v_challenge.challenger_id = v_player_id
             THEN v_challenge.challenged_id
             ELSE v_challenge.challenger_id
        END,
        'general',
        'Desafio Cancelado',
        'O oponente saiu do ranking. O desafio foi cancelado automaticamente.',
        jsonb_build_object('challenge_id', v_challenge.id),
        p_club_id
      );
    END LOOP;

    -- Remove from ranking
    UPDATE club_members
    SET ranking_position = NULL, ranking_opt_in = FALSE
    WHERE id = v_member.id;

    -- Recompact ranking: shift everyone above down
    WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY ranking_position) AS new_pos
      FROM club_members
      WHERE club_id = p_club_id AND sport_id = p_sport_id
        AND status = 'active' AND ranking_position IS NOT NULL
    )
    UPDATE club_members cm
    SET ranking_position = ranked.new_pos
    FROM ranked
    WHERE cm.id = ranked.id;

    -- Record in ranking_history
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_player_id, v_old_position, NULL, 'ranking_opt_out', v_member.id, p_club_id, p_sport_id);

    -- Notify player
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_player_id,
      'general',
      'Ranking Desativado',
      'Voce saiu do ranking. Seus desafios ativos foram cancelados.',
      jsonb_build_object('club_id', p_club_id, 'sport_id', p_sport_id),
      p_club_id
    );

  -- ==================== OPT-IN ====================
  ELSE
    IF v_member.ranking_position IS NOT NULL THEN
      RAISE EXCEPTION 'Voce ja esta no ranking';
    END IF;

    -- Get last position + 1
    SELECT COALESCE(MAX(ranking_position), 0) + 1 INTO v_new_position
    FROM club_members
    WHERE club_id = p_club_id AND sport_id = p_sport_id
      AND status = 'active' AND ranking_position IS NOT NULL;

    -- Add to ranking
    UPDATE club_members
    SET ranking_position = v_new_position, ranking_opt_in = TRUE
    WHERE id = v_member.id;

    -- Record in ranking_history
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id, club_id, sport_id)
    VALUES (v_player_id, NULL, v_new_position, 'ranking_opt_in', v_member.id, p_club_id, p_sport_id);

    -- Notify player
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_player_id,
      'general',
      'Ranking Ativado',
      format('Voce entrou no ranking na posicao #%s.', v_new_position),
      jsonb_build_object('club_id', p_club_id, 'sport_id', p_sport_id, 'position', v_new_position),
      p_club_id
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: create_challenge
-- Add ranking_position NULL check for opted-out players
-- ============================================================
CREATE OR REPLACE FUNCTION create_challenge(
  p_challenger_auth_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_challenger_id UUID;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
  v_challenger_member RECORD;
  v_challenged_member RECORD;
  v_active_challenge_count INT;
  v_rule_position_gap BOOLEAN;
  v_rule_cooldown BOOLEAN;
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  -- Fetch rules for this club+sport
  SELECT rule_position_gap_enabled, rule_cooldown_enabled
  INTO v_rule_position_gap, v_rule_cooldown
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  -- Get challenger membership for this sport
  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste esporte neste clube';
  END IF;

  -- Get challenged membership for this sport
  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador desafiado nao e membro ativo deste esporte neste clube';
  END IF;

  -- NEW: Validate ranking participation
  IF v_challenger_member.ranking_position IS NULL THEN
    RAISE EXCEPTION 'Voce nao esta no ranking. Ative sua participacao para desafiar.';
  END IF;
  IF v_challenged_member.ranking_position IS NULL THEN
    RAISE EXCEPTION 'Jogador desafiado nao esta no ranking';
  END IF;

  IF (SELECT status FROM players WHERE id = v_challenger_id) != 'active' THEN
    RAISE EXCEPTION 'Jogador nao esta ativo';
  END IF;
  IF (SELECT status FROM players WHERE id = p_challenged_id) NOT IN ('active') THEN
    RAISE EXCEPTION 'Jogador desafiado nao esta disponivel';
  END IF;
  IF (SELECT fee_status FROM players WHERE id = v_challenger_id) = 'overdue' THEN
    RAISE EXCEPTION 'Mensalidade em atraso. Regularize para desafiar.';
  END IF;
  IF v_challenger_member.must_be_challenged_first THEN
    RAISE EXCEPTION 'Voce deve ser desafiado primeiro apos retornar da ambulancia';
  END IF;

  v_challenger_pos := v_challenger_member.ranking_position;
  v_challenged_pos := v_challenged_member.ranking_position;

  -- CONDITIONAL: Position gap check (only if rule enabled)
  IF v_rule_position_gap AND v_challenger_pos - v_challenged_pos > 2 THEN
    RAISE EXCEPTION 'So pode desafiar jogadores ate 2 posicoes a frente';
  END IF;

  -- Always enforce: must challenge upward
  IF v_challenged_pos >= v_challenger_pos THEN
    RAISE EXCEPTION 'So pode desafiar jogadores acima no ranking';
  END IF;

  -- CONDITIONAL: Cooldown checks (only if rule enabled)
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
    END IF;
    IF v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      RAISE EXCEPTION 'Este jogador esta protegido temporariamente';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = v_challenger_id OR challenged_id = v_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo neste esporte';
  END IF;

  INSERT INTO challenges (
    challenger_id, challenged_id, club_id, sport_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    v_challenger_id, p_challenged_id, p_club_id, p_sport_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    p_challenged_id, 'challenge_received', 'Novo Desafio!',
    format('Voce foi desafiado pelo jogador da posicao #%s. Responda em 48h.', v_challenger_pos),
    jsonb_build_object('challenge_id', v_challenge_id),
    p_club_id
  );

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- UPDATED RPC: validate_challenge_creation
-- Add ranking_position NULL check for opted-out players
-- ============================================================
CREATE OR REPLACE FUNCTION validate_challenge_creation(
  p_challenger_id UUID,
  p_challenged_id UUID,
  p_club_id UUID DEFAULT NULL,
  p_sport_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_challenger RECORD;
  v_challenged RECORD;
  v_challenger_member RECORD;
  v_challenged_member RECORD;
  v_active_challenge_count INT;
  v_rule_position_gap BOOLEAN;
  v_rule_cooldown BOOLEAN;
BEGIN
  IF p_club_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'club_id e obrigatorio');
  END IF;
  IF p_sport_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'sport_id e obrigatorio');
  END IF;

  -- Fetch rules
  SELECT rule_position_gap_enabled, rule_cooldown_enabled
  INTO v_rule_position_gap, v_rule_cooldown
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiante nao e membro deste esporte');
  END IF;

  SELECT * INTO v_challenged_member FROM club_members
  WHERE club_id = p_club_id AND player_id = p_challenged_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Desafiado nao e membro deste esporte');
  END IF;

  -- NEW: Validate ranking participation
  IF v_challenger_member.ranking_position IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Voce nao esta no ranking. Ative sua participacao para desafiar.');
  END IF;
  IF v_challenged_member.ranking_position IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta no ranking');
  END IF;

  IF v_challenger.status != 'active' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador nao esta ativo');
  END IF;
  IF v_challenged.status NOT IN ('active') THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta disponivel');
  END IF;
  IF v_challenger.fee_status = 'overdue' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Mensalidade em atraso.');
  END IF;
  IF v_challenger_member.must_be_challenged_first THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Voce deve ser desafiado primeiro apos retornar da ambulancia');
  END IF;

  -- CONDITIONAL: Position gap
  IF v_rule_position_gap AND v_challenger_member.ranking_position - v_challenged_member.ranking_position > 2 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;

  IF v_challenged_member.ranking_position >= v_challenger_member.ranking_position THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'So pode desafiar jogadores acima no ranking');
  END IF;

  -- CONDITIONAL: Cooldown
  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RETURN jsonb_build_object('valid', FALSE, 'error',
        format('Cooldown ativo ate %s', v_challenger_member.challenger_cooldown_until));
    END IF;
    IF v_challenged_member.challenged_protection_until IS NOT NULL
       AND v_challenged_member.challenged_protection_until > now() THEN
      RETURN jsonb_build_object('valid', FALSE, 'error', 'Este jogador esta protegido temporariamente');
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste esporte');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
