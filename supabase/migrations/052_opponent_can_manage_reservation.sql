-- ============================================================
-- Migration 052: adversario tambem manda na reserva amistosa
-- ============================================================
-- Relatado no grupo em 15/09: o Guilherme tinha jogo com o Fabio (15/09 17:15,
-- Quadra 2) e nao conseguia desmarcar — o slot aparecia com CADEADO pra ele.
-- Motivo: a reserva foi criada pelo Fabio (reserved_by = Fabio, opponent_id =
-- Guilherme). O app so libera acao pra quem criou, e a RLS tambem: a policy de
-- UPDATE aceita dono, admin, club admin, vaga aberta ou participante de
-- DESAFIO — mas nao o adversario de uma reserva amistosa. Resultado: o jogador
-- fica preso num jogo que ele nao pode cancelar, e o horario da quadra segue
-- ocupado por um jogo que ninguem vai jogar.
--
-- Correcao: quem esta declarado como adversario (opponent_type = 'member')
-- pode mexer na reserva igual ao dono. Os dois estao jogando.
--
-- Aditivo: so amplia a condicao; ninguem perde acesso.
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

DROP POLICY IF EXISTS reservations_update ON court_reservations;
CREATE POLICY reservations_update ON court_reservations
  FOR UPDATE TO authenticated
  USING (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id IS NULL AND challenge_id IS NULL)
    OR (opponent_id = get_player_id() AND opponent_type = 'member')
    OR (
      challenge_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM challenges ch
        WHERE ch.id = court_reservations.challenge_id
          AND (ch.challenger_id = get_player_id()
               OR ch.challenged_id = get_player_id())
      )
    )
  )
  WITH CHECK (
    reserved_by = get_player_id()
    OR is_admin()
    OR is_club_admin(club_id)
    OR (opponent_id = get_player_id() AND opponent_type = 'member')
    OR (
      challenge_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM challenges ch
        WHERE ch.id = court_reservations.challenge_id
          AND (ch.challenger_id = get_player_id()
               OR ch.challenged_id = get_player_id())
      )
    )
  );
