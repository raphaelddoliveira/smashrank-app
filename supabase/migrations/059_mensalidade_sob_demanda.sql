-- ============================================================
-- Migration 059: mensalidade criada sob demanda, no clique de pagar
-- ============================================================
-- Decisao do Rodolfo: nada de gerar lote mensal. A mensalidade nasce quando o
-- jogador abre a tela de pagamento. Assim ninguem precisa lembrar de rodar
-- nada todo mes, e a cobranca na Cora — que e o que tem custo — so e emitida
-- no clique, pelo servico de cobranca.
--
-- Aqui NAO se fala com a Cora: esta funcao so cria a linha em monthly_fees,
-- que e registro no nosso banco e nao custa nada.
--
-- Valor e dia de vencimento viram configuracao do clube, preenchida uma vez
-- pelo administrador no painel.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS monthly_fee_amount  numeric(10,2),
  ADD COLUMN IF NOT EXISTS monthly_fee_due_day int;

COMMENT ON COLUMN clubs.monthly_fee_amount IS
  'Valor da mensalidade. NULL = cobranca pelo app desligada para este clube.';
COMMENT ON COLUMN clubs.monthly_fee_due_day IS
  'Dia do mes do vencimento (1-28). O Zinho falou em inativar quem nao pagou ate o dia 10.';

ALTER TABLE clubs
  DROP CONSTRAINT IF EXISTS chk_dia_vencimento;
ALTER TABLE clubs
  ADD CONSTRAINT chk_dia_vencimento
  CHECK (monthly_fee_due_day IS NULL OR monthly_fee_due_day BETWEEN 1 AND 28);

-- ── Mensalidade do mes do proprio jogador, criando se ainda nao existir ─────
CREATE OR REPLACE FUNCTION mensalidade_do_mes(
  p_club_id uuid,
  p_mes     date DEFAULT NULL   -- qualquer dia do mes; padrao = mes corrente
)
RETURNS monthly_fees
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me       uuid := get_player_id();
  v_mes      date := date_trunc('month', coalesce(p_mes, current_date))::date;
  v_valor    numeric(10,2);
  v_dia      int;
  v_venc     date;
  v_fee      monthly_fees%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Jogador nao identificado' USING ERRCODE = '42501';
  END IF;

  -- ja existe? devolve e nao cria outra
  SELECT * INTO v_fee
  FROM monthly_fees
  WHERE player_id = v_me AND reference_month = v_mes;
  IF FOUND THEN
    RETURN v_fee;
  END IF;

  SELECT monthly_fee_amount, monthly_fee_due_day
    INTO v_valor, v_dia
  FROM clubs WHERE id = p_club_id;

  IF v_valor IS NULL OR v_dia IS NULL THEN
    RAISE EXCEPTION 'O clube ainda nao configurou valor e vencimento da mensalidade'
      USING ERRCODE = '22023';
  END IF;

  -- so membro ativo do clube gera mensalidade
  IF NOT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id AND player_id = v_me AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Voce nao e membro ativo deste clube' USING ERRCODE = '42501';
  END IF;

  v_venc := v_mes + (v_dia - 1);

  INSERT INTO monthly_fees
    (player_id, reference_month, amount, due_date, status, description)
  VALUES
    (v_me, v_mes, v_valor, v_venc, 'pending',
     'Mensalidade ' || to_char(v_mes, 'MM/YYYY'))
  ON CONFLICT (player_id, reference_month) DO NOTHING;

  SELECT * INTO v_fee
  FROM monthly_fees
  WHERE player_id = v_me AND reference_month = v_mes;

  RETURN v_fee;
END;
$$;

GRANT EXECUTE ON FUNCTION mensalidade_do_mes(uuid, date) TO authenticated;

-- ── RLS: cada um ve a sua; admin do clube ve todas ──────────────────────────
ALTER TABLE monthly_fees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mensalidades_select ON monthly_fees;
CREATE POLICY mensalidades_select ON monthly_fees
  FOR SELECT TO authenticated
  USING (
    player_id = get_player_id()
    OR is_admin()
    OR EXISTS (
      SELECT 1 FROM club_members cm
      WHERE cm.player_id = monthly_fees.player_id
        AND is_club_admin(cm.club_id)
    )
  );
