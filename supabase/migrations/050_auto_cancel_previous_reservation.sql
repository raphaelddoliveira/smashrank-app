-- ============================================================
-- Migration 050: cancelar a reserva anterior do desafio no proprio banco
-- ============================================================
-- URGENTE. A 049 criou o indice unico uniq_active_reservation_per_challenge,
-- que impede duas reservas ativas no mesmo desafio. Mas o app publicado ainda
-- e o codigo ANTIGO, que tenta cancelar a reserva anterior com UPDATE direto
-- — e esse UPDATE bate em 0 linhas quando a reserva e do outro participante
-- (RLS). Resultado em producao (01/09, Guilherme reagendando por chuva):
--
--   AppException(23505): duplicate key value violates unique constraint
--   "uniq_active_reservation_per_challenge"
--
-- Ou seja: em vez de duplicar em silencio, agora o reagendamento FALHA.
--
-- Correcao: garantir a regra no banco, independente da versao do app. Um
-- trigger BEFORE INSERT cancela qualquer outra reserva ativa do mesmo desafio
-- antes de a nova entrar. Assim:
--   - app antigo (hoje em producao): volta a reagendar normalmente, e sem
--     deixar reserva fantasma;
--   - app novo (quando o deploy sair): as RPCs da 049 continuam valendo, o
--     trigger so nao acha nada pra cancelar.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn) o quanto antes —
-- enquanto nao rodar, os jogadores nao conseguem reagendar desafio.
-- ============================================================

CREATE OR REPLACE FUNCTION cancel_previous_challenge_reservation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.challenge_id IS NOT NULL AND NEW.status = 'confirmed' THEN
    UPDATE court_reservations
    SET status = 'cancelled',
        updated_at = now(),
        notes = coalesce(notes || ' | ', '')
                || 'cancelada automaticamente (nova reserva do mesmo desafio)'
    WHERE challenge_id = NEW.challenge_id
      AND status = 'confirmed'
      AND id <> NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cancel_previous_challenge_reservation ON court_reservations;
CREATE TRIGGER trg_cancel_previous_challenge_reservation
  BEFORE INSERT ON court_reservations
  FOR EACH ROW
  EXECUTE FUNCTION cancel_previous_challenge_reservation();
