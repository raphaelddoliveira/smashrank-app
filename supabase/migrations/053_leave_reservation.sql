-- ============================================================
-- Migration 053: sair da reserva sem cancelar o jogo do outro
-- ============================================================
-- Relatado no grupo em 15/09, testando o build do mesmo dia:
--   "nao tira so eu da reserva / so tira os dois"
-- A 052 liberou o adversario a agir na reserva, mas a unica acao existente
-- cancela a reserva inteira — some pros dois. O que falta e sair e deixar a
-- VAGA ABERTA, com o dono mantendo o horario pra chamar outra pessoa.
--
-- Nao da pra fazer com UPDATE direto: ao limpar o proprio nome, a linha
-- resultante nao tem mais vinculo com quem esta editando e o WITH CHECK da
-- policy rejeita. Por isso a operacao vira RPC SECURITY DEFINER, restrita:
--   - so reserva amistosa (challenge_id IS NULL; desafio de ranking nao sai
--     no grito, continua sendo coisa de admin)
--   - so quem esta declarado como adversario membro daquela reserva
--   - so reserva confirmada
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

CREATE OR REPLACE FUNCTION leave_reservation(p_reservation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := get_player_id();
  v_res court_reservations%ROWTYPE;
BEGIN
  SELECT * INTO v_res FROM court_reservations WHERE id = p_reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva nao encontrada' USING ERRCODE = 'P0002';
  END IF;

  IF v_res.challenge_id IS NOT NULL THEN
    RAISE EXCEPTION 'Desafio de ranking nao pode ser desfeito por aqui'
      USING ERRCODE = '42501';
  END IF;

  IF v_res.status <> 'confirmed' THEN
    RAISE EXCEPTION 'Esta reserva nao esta ativa' USING ERRCODE = '42501';
  END IF;

  IF v_res.opponent_id IS DISTINCT FROM v_me OR v_res.opponent_type <> 'member' THEN
    RAISE EXCEPTION 'Voce nao esta nesta reserva como adversario'
      USING ERRCODE = '42501';
  END IF;

  -- Sai e devolve a vaga: a reserva segue de pe, no nome de quem criou.
  UPDATE court_reservations
  SET opponent_id = NULL,
      opponent_type = NULL,
      opponent_name = NULL,
      updated_at = now()
  WHERE id = p_reservation_id;

  -- Avisa o dono que a vaga abriu
  INSERT INTO notifications (player_id, type, title, body, data, club_id)
  VALUES (
    v_res.reserved_by,
    'general',
    'Vaga aberta na sua reserva',
    'Seu adversario saiu do jogo. O horario continua reservado no seu nome e a vaga esta aberta para outro jogador.',
    jsonb_build_object('reservation_id', p_reservation_id),
    v_res.club_id
  );

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION leave_reservation(uuid) TO authenticated;
