-- ============================================================
-- Migration 060: WO volta a ativar os escudos (cooldown e protecao)
-- ============================================================
-- Relatado pelo Zinho no grupo (05/10 09:19):
--   "sobre as 48hr pra colocar a data do jogo OKKKK, porem tem que ativar os
--    escudos apos o WO. Tivemos 1 WO e nao apareceu o escudo das 48hr e nem
--    das 24h"
--
-- Causa: fui eu. A 054 tirou a chamada de swap_ranking_after_challenge do
-- expire_pending_challenges para o WO parar de mexer no ranking — e era essa
-- funcao que, de quebra, gravava o cooldown de 48h do desafiante e a protecao
-- de 24h do desafiado. Tirei o ranking e levei os escudos junto.
-- Confirmado no WO de 04/10 (adalberto -> Tim): nenhum dos dois teve escudo
-- atualizado.
--
-- Agora o WO automatico grava os escudos SEM tocar no ranking:
--   - desafiante: 48h de cooldown
--   - desafiado: 24h de protecao
-- Ancorados em now(), porque num WO por falta de resposta nao houve jogo e
-- portanto nao existe horario de inicio para contar (quando ha jogo, a regra
-- continua contando a partir do horario marcado, como o clube pediu).
--
-- Respeita o interruptor rule_cooldown_enabled do esporte e a regra da 039:
-- o #1 do ranking nao recebe protecao, para seguir sempre desafiavel.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

CREATE OR REPLACE FUNCTION expire_pending_challenges()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_challenge RECORD;
  v_rule_cooldown BOOLEAN;
  v_pos_desafiado INT;
BEGIN
  FOR v_challenge IN
    SELECT * FROM challenges
    WHERE status = 'pending'
      AND response_deadline < now()
  LOOP
    UPDATE challenges
    SET status = 'wo_challenged',
        wo_player_id = v_challenge.challenged_id,
        completed_at = now()
    WHERE id = v_challenge.id;

    SELECT rule_cooldown_enabled INTO v_rule_cooldown
    FROM club_sports
    WHERE club_id = v_challenge.club_id AND sport_id = v_challenge.sport_id;
    v_rule_cooldown := COALESCE(v_rule_cooldown, true);

    IF v_rule_cooldown THEN
      -- desafiante: 48h sem poder desafiar de novo
      UPDATE club_members
      SET challenger_cooldown_until = now() + INTERVAL '48 hours',
          last_challenge_date = now()
      WHERE club_id = v_challenge.club_id
        AND sport_id = v_challenge.sport_id
        AND player_id = v_challenge.challenger_id;

      -- desafiado: 24h de protecao, menos se for o #1 (regra da 039)
      SELECT ranking_position INTO v_pos_desafiado
      FROM club_members
      WHERE club_id = v_challenge.club_id
        AND sport_id = v_challenge.sport_id
        AND player_id = v_challenge.challenged_id;

      IF COALESCE(v_pos_desafiado, 0) <> 1 THEN
        UPDATE club_members
        SET challenged_protection_until = now() + INTERVAL '24 hours'
        WHERE club_id = v_challenge.club_id
          AND sport_id = v_challenge.sport_id
          AND player_id = v_challenge.challenged_id;
      END IF;
    END IF;

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
