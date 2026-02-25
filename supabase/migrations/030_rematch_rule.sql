-- ============================================================
-- Rule: Rematch restriction
-- A cannot challenge B again until B has played a challenge
-- with a different opponent since their last match together.
-- ============================================================

-- Add toggle to club_sports (default enabled)
ALTER TABLE club_sports
  ADD COLUMN IF NOT EXISTS rule_rematch_restriction_enabled BOOLEAN NOT NULL DEFAULT true;

-- ============================================================
-- UPDATED RPC: create_challenge
-- Adds rematch restriction check
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
  v_rule_rematch BOOLEAN;
  v_last_match_date TIMESTAMPTZ;
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  -- Fetch rules for this club+sport
  SELECT rule_position_gap_enabled, rule_cooldown_enabled,
         COALESCE(rule_rematch_restriction_enabled, true)
  INTO v_rule_position_gap, v_rule_cooldown, v_rule_rematch
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);
  v_rule_rematch := COALESCE(v_rule_rematch, true);

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

  -- Active challenge check
  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled', 'pending_result')
    AND (challenger_id = v_challenger_id OR challenged_id = v_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo neste esporte';
  END IF;

  -- CONDITIONAL: Rematch restriction
  -- A cannot challenge B again until B has played with someone else
  IF v_rule_rematch THEN
    SELECT MAX(completed_at) INTO v_last_match_date
    FROM challenges
    WHERE club_id = p_club_id AND sport_id = p_sport_id
      AND status = 'completed'
      AND (
        (challenger_id = v_challenger_id AND challenged_id = p_challenged_id)
        OR (challenger_id = p_challenged_id AND challenged_id = v_challenger_id)
      );

    IF v_last_match_date IS NOT NULL THEN
      -- Check if challenged player has played with someone else after that
      IF NOT EXISTS (
        SELECT 1 FROM challenges
        WHERE club_id = p_club_id AND sport_id = p_sport_id
          AND status = 'completed'
          AND completed_at > v_last_match_date
          AND (
            (challenger_id = p_challenged_id AND challenged_id != v_challenger_id)
            OR (challenged_id = p_challenged_id AND challenger_id != v_challenger_id)
          )
      ) THEN
        RAISE EXCEPTION 'Voce ja desafiou este jogador recentemente. Aguarde ate ele jogar com outro oponente.';
      END IF;
    END IF;
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
-- Adds rematch restriction check
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
  v_rule_rematch BOOLEAN;
  v_last_match_date TIMESTAMPTZ;
BEGIN
  IF p_club_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'club_id e obrigatorio');
  END IF;
  IF p_sport_id IS NULL THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'sport_id e obrigatorio');
  END IF;

  -- Fetch rules
  SELECT rule_position_gap_enabled, rule_cooldown_enabled,
         COALESCE(rule_rematch_restriction_enabled, true)
  INTO v_rule_position_gap, v_rule_cooldown, v_rule_rematch
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);
  v_rule_rematch := COALESCE(v_rule_rematch, true);

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

  -- Active challenge check
  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled', 'pending_result')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Um dos jogadores ja possui um desafio ativo neste esporte');
  END IF;

  -- CONDITIONAL: Rematch restriction
  IF v_rule_rematch THEN
    SELECT MAX(completed_at) INTO v_last_match_date
    FROM challenges
    WHERE club_id = p_club_id AND sport_id = p_sport_id
      AND status = 'completed'
      AND (
        (challenger_id = p_challenger_id AND challenged_id = p_challenged_id)
        OR (challenger_id = p_challenged_id AND challenged_id = p_challenger_id)
      );

    IF v_last_match_date IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM challenges
        WHERE club_id = p_club_id AND sport_id = p_sport_id
          AND status = 'completed'
          AND completed_at > v_last_match_date
          AND (
            (challenger_id = p_challenged_id AND challenged_id != p_challenger_id)
            OR (challenged_id = p_challenged_id AND challenger_id != p_challenger_id)
          )
      ) THEN
        RETURN jsonb_build_object('valid', FALSE, 'error',
          'Voce ja desafiou este jogador recentemente. Aguarde ate ele jogar com outro oponente.');
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
