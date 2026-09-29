-- ============================================================
-- Migration 057: adiamento por chuva passa a depender de aprovacao do admin
-- ============================================================
-- Pedido do Zinho no grupo (29/09 13:00):
--   "ficou decidido que iria aparecer uma solicitacao para os ADM liberar
--    (autorizar), pois tinha jogador usando a opcao sem ter chovido somente
--    pra prorrogar jogo"
--
-- Ate aqui o jogador tocava no botao e o prazo era esticado na hora. A trava
-- da 051 (um adiamento por data agendada) limita o abuso, mas nao exige
-- autorizacao — que e o que o clube quer.
--
-- Agora: o jogador SOLICITA, o prazo NAO muda, os administradores do clube
-- sao notificados e um deles libera ou recusa. So na liberacao o prazo e
-- esticado (+3 dias no 1o uso do desafio, +1 nos seguintes, como ja era).
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

CREATE TABLE IF NOT EXISTS weather_extension_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id  uuid NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  club_id       uuid REFERENCES clubs(id),
  requested_by  uuid NOT NULL REFERENCES players(id),
  requested_for timestamptz,            -- chosen_date do jogo na hora do pedido
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected')),
  days_granted  int,
  reviewed_by   uuid REFERENCES players(id),
  reviewed_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- um pedido em aberto por desafio
CREATE UNIQUE INDEX IF NOT EXISTS uniq_pedido_chuva_aberto
  ON weather_extension_requests (challenge_id)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_pedido_chuva_desafio
  ON weather_extension_requests (challenge_id, status);

ALTER TABLE weather_extension_requests ENABLE ROW LEVEL SECURITY;

-- Leitura: participantes do desafio e admins do clube
DROP POLICY IF EXISTS pedido_chuva_select ON weather_extension_requests;
CREATE POLICY pedido_chuva_select ON weather_extension_requests
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR is_club_admin(club_id)
    OR EXISTS (
      SELECT 1 FROM challenges ch
      WHERE ch.id = weather_extension_requests.challenge_id
        AND (ch.challenger_id = get_player_id() OR ch.challenged_id = get_player_id())
    )
  );

-- Escrita so pelas RPCs abaixo (SECURITY DEFINER); nada de INSERT/UPDATE direto.

-- ── Solicitar ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION request_weather_extension(p_challenge_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := get_player_id();
  v_ch challenges%ROWTYPE;
  v_id uuid;
  v_admin RECORD;
BEGIN
  SELECT * INTO v_ch FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Desafio nao encontrado' USING ERRCODE = 'P0002';
  END IF;

  IF v_ch.challenger_id <> v_me AND v_ch.challenged_id <> v_me
     AND NOT is_admin() AND NOT is_club_admin(v_ch.club_id) THEN
    RAISE EXCEPTION 'Voce nao participa deste desafio' USING ERRCODE = '42501';
  END IF;

  IF v_ch.status <> 'scheduled' THEN
    RAISE EXCEPTION 'So da para pedir adiamento de jogo agendado'
      USING ERRCODE = '42501';
  END IF;

  IF v_ch.weather_extended_for IS NOT NULL
     AND v_ch.chosen_date IS NOT NULL
     AND v_ch.weather_extended_for = v_ch.chosen_date THEN
    RAISE EXCEPTION 'Este jogo ja foi adiado por chuva. Reagende para uma nova data antes de pedir outro adiamento.'
      USING ERRCODE = '42501';
  END IF;

  IF EXISTS (SELECT 1 FROM weather_extension_requests
             WHERE challenge_id = p_challenge_id AND status = 'pending') THEN
    RAISE EXCEPTION 'Ja existe um pedido aguardando liberacao do administrador'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO weather_extension_requests
    (challenge_id, club_id, requested_by, requested_for)
  VALUES (p_challenge_id, v_ch.club_id, v_me, v_ch.chosen_date)
  RETURNING id INTO v_id;

  -- avisa os administradores do clube
  FOR v_admin IN
    SELECT player_id FROM club_members
    WHERE club_id = v_ch.club_id AND role = 'admin' AND status = 'active'
  LOOP
    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_admin.player_id, 'general', 'Pedido de adiamento por chuva',
      'Um jogador pediu adiamento por chuva. Libere ou recuse pelo detalhe do desafio.',
      jsonb_build_object('challenge_id', p_challenge_id, 'request_id', v_id),
      v_ch.club_id
    );
  END LOOP;

  RETURN v_id;
END;
$$;

-- ── Liberar ou recusar ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION review_weather_extension(
  p_request_id uuid,
  p_approve boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req weather_extension_requests%ROWTYPE;
  v_ch  challenges%ROWTYPE;
  v_dias int;
  v_outro uuid;
BEGIN
  SELECT * INTO v_req FROM weather_extension_requests WHERE id = p_request_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pedido nao encontrado' USING ERRCODE = 'P0002';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Este pedido ja foi respondido' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_ch FROM challenges WHERE id = v_req.challenge_id;

  IF NOT is_admin() AND NOT is_club_admin(v_ch.club_id) THEN
    RAISE EXCEPTION 'So um administrador do clube pode liberar o adiamento'
      USING ERRCODE = '42501';
  END IF;

  IF p_approve THEN
    v_dias := CASE WHEN COALESCE(v_ch.weather_extension_days, 0) = 0 THEN 3 ELSE 1 END;

    UPDATE challenges
    SET weather_extension_days = COALESCE(weather_extension_days, 0) + v_dias,
        play_deadline = play_deadline + (v_dias || ' days')::interval,
        weather_extended_for = chosen_date
    WHERE id = v_ch.id;

    UPDATE weather_extension_requests
    SET status = 'approved', days_granted = v_dias,
        reviewed_by = get_player_id(), reviewed_at = now()
    WHERE id = p_request_id;

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    SELECT p, 'general', 'Adiamento por chuva liberado',
           'O administrador liberou o adiamento. O prazo para jogar aumentou em +'
             || v_dias || CASE WHEN v_dias > 1 THEN ' dias.' ELSE ' dia.' END,
           jsonb_build_object('challenge_id', v_ch.id), v_ch.club_id
    FROM unnest(ARRAY[v_ch.challenger_id, v_ch.challenged_id]) AS p;
  ELSE
    UPDATE weather_extension_requests
    SET status = 'rejected',
        reviewed_by = get_player_id(), reviewed_at = now()
    WHERE id = p_request_id;

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_req.requested_by, 'general', 'Adiamento por chuva recusado',
      'O administrador nao liberou o adiamento. O prazo para jogar continua o mesmo.',
      jsonb_build_object('challenge_id', v_ch.id), v_ch.club_id
    );
  END IF;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION request_weather_extension(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION review_weather_extension(uuid, boolean) TO authenticated;
