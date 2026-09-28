-- ============================================================
-- Migration 056: prazo de resposta volta para 48h
-- ============================================================
-- Reverte a 055. Audio do Zinho no grupo em 28/09 08:36:
--   "Rodolfo, so altera essas 24 horas ai para 48, que e o que a gente tinha
--    conversado e deixado alinhado. Eu ja comuniquei todos os membros, tanto
--    no PV como no grupo. 24 fica muito curta, 48 horas ta otimo."
--
-- A 055 (24h) chegou a valer entre a data em que foi aplicada e agora; os
-- desafios criados nesse intervalo carregam o prazo de 24h gravado neles e
-- nao sao alterados — mexer no prazo de desafio em andamento mudaria a regra
-- no meio do jogo. Daqui pra frente, desafio novo nasce com 48h.
--
-- O WO permanece como esta: encerra o desafio sem mexer no ranking (054),
-- confirmado no mesmo audio ("o WO ta certinho, quem desafiou, se nao houve
-- resposta, continua no mesmo lugar, porque ele tem que ir atras").
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
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

  -- SELF-CHALLENGE CHECK
  IF v_challenger_id = p_challenged_id THEN
    RAISE EXCEPTION 'Voce nao pode desafiar a si mesmo';
  END IF;

  IF p_club_id IS NULL THEN RAISE EXCEPTION 'club_id e obrigatorio'; END IF;
  IF p_sport_id IS NULL THEN RAISE EXCEPTION 'sport_id e obrigatorio'; END IF;

  SELECT rule_position_gap_enabled, rule_cooldown_enabled
  INTO v_rule_position_gap, v_rule_cooldown
  FROM club_sports
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND is_active = true;

  v_rule_position_gap := COALESCE(v_rule_position_gap, true);
  v_rule_cooldown := COALESCE(v_rule_cooldown, true);

  SELECT * INTO v_challenger_member FROM club_members
  WHERE club_id = p_club_id AND player_id = v_challenger_id AND sport_id = p_sport_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste esporte neste clube';
  END IF;

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

  IF v_rule_position_gap AND v_challenger_pos - v_challenged_pos > 2 THEN
    RAISE EXCEPTION 'So pode desafiar jogadores ate 2 posicoes a frente';
  END IF;

  IF v_challenged_pos >= v_challenger_pos THEN
    RAISE EXCEPTION 'So pode desafiar jogadores acima no ranking';
  END IF;

  IF v_rule_cooldown THEN
    IF v_challenger_member.challenger_cooldown_until IS NOT NULL
       AND v_challenger_member.challenger_cooldown_until > now() THEN
      RAISE EXCEPTION 'Cooldown ativo ate %', v_challenger_member.challenger_cooldown_until;
    END IF;
    IF v_challenged_pos > 1
       AND v_challenged_member.challenged_protection_until IS NOT NULL
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

-- Fix admin_create_challenge
CREATE OR REPLACE FUNCTION admin_create_challenge(
  p_admin_auth_id UUID,
  p_challenger_id UUID,
  p_challenged_id UUID,
  p_club_id UUID,
  p_sport_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_admin_id UUID;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
  v_active_count INT;
BEGIN
  -- SELF-CHALLENGE CHECK
  IF p_challenger_id = p_challenged_id THEN
    RAISE EXCEPTION 'Desafiante e desafiado nao podem ser a mesma pessoa';
  END IF;

  SELECT id INTO v_admin_id FROM players WHERE auth_id = p_admin_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin nao encontrado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = v_admin_id AND role = 'admin' AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Apenas administradores podem criar desafios em nome de outros';
  END IF;

  SELECT ranking_position INTO v_challenger_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_challenger_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafiante nao e membro ativo deste esporte';
  END IF;

  SELECT ranking_position INTO v_challenged_pos FROM club_members
  WHERE club_id = p_club_id AND sport_id = p_sport_id AND player_id = p_challenged_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafiado nao e membro ativo deste esporte';
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM challenges
  WHERE club_id = p_club_id AND sport_id = p_sport_id
    AND status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_count > 0 THEN
    RAISE EXCEPTION 'Um dos jogadores ja possui um desafio ativo. Cancele ou edite o existente.';
  END IF;

  INSERT INTO challenges (
    challenger_id, challenged_id, club_id, sport_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    p_challenger_id, p_challenged_id, p_club_id, p_sport_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES
    (p_challenger_id, 'challenge_received', 'Novo Desafio (Admin)',
     format('O administrador criou um desafio para voce contra o jogador #%s.', v_challenged_pos),
     jsonb_build_object('challenge_id', v_challenge_id), p_club_id),
    (p_challenged_id, 'challenge_received', 'Novo Desafio (Admin)',
     format('O administrador criou um desafio. Voce foi desafiado pelo jogador #%s.', v_challenger_pos),
     jsonb_build_object('challenge_id', v_challenge_id), p_club_id);

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
