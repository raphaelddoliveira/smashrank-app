-- ============================================================
-- Migration 054: WO por falta de resposta nao mexe no ranking
-- ============================================================
-- Pedido do Zinho em audio no grupo (21/09 18:22):
--   "e o WO, quando acontecer, quem desafiou continua na mesma posicao,
--    nao sobe nao"
--
-- Hoje expire_pending_challenges chama swap_ranking_after_challenge, que
-- registra uma partida e FAZ a troca de posicoes — o desafiante sobe para a
-- posicao do desafiado como se tivesse vencido em quadra. A regra do clube e
-- outra: ninguem jogou, entao o ranking fica como esta. O desafio so e
-- encerrado como WO e os dois sao avisados.
--
-- Muda so o WO AUTOMATICO (desafiado nao respondeu no prazo). O WO manual
-- (record_wo, usado quando o adversario nao aparece no jogo marcado) segue
-- como esta, porque ali houve jogo marcado e falta de comparecimento — se o
-- clube quiser a mesma regra la, e so pedir.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
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
    -- Encerra como WO do desafiado, SEM tocar no ranking e sem registrar
    -- partida: nao houve jogo.
    UPDATE challenges
    SET status = 'wo_challenged',
        wo_player_id = v_challenge.challenged_id,
        completed_at = now()
    WHERE id = v_challenge.id;

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_challenge.challenged_id, 'wo_warning', 'WO - Desafio Expirado',
      'Voce nao respondeu ao desafio no prazo e perdeu por WO. O ranking nao muda.',
      jsonb_build_object('challenge_id', v_challenge.id),
      v_challenge.club_id
    );

    INSERT INTO notifications (player_id, type, title, body, data, club_id)
    VALUES (
      v_challenge.challenger_id, 'general', 'Desafio encerrado por WO',
      'Seu adversario nao respondeu no prazo. O desafio foi encerrado por WO e o ranking permanece o mesmo.',
      jsonb_build_object('challenge_id', v_challenge.id),
      v_challenge.club_id
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION expire_pending_challenges() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION expire_pending_challenges() FROM anon;
GRANT EXECUTE ON FUNCTION expire_pending_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION expire_pending_challenges() TO service_role;
