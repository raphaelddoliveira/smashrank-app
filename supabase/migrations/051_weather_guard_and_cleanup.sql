-- ============================================================
-- Migration 051: guarda do adiamento por chuva, limpeza e permissao do expire
-- ============================================================
-- 1) BUG relatado no grupo em 03/09 ("deu esse BO ai de 13 dias"):
--    o desafio Heverton x Guilherme ficou com "Extensao por chuva +13 dias".
--    O botao de adiamento aparece em QUALQUER dia dentro do prazo e nao tem
--    limite: cada toque soma +3 (1o uso) ou +1 (demais). Como o reagendamento
--    estava dando erro 23505 nos dias 01-02/09, o jogador foi clicando no
--    adiamento — 3 + 10 toques = 13 dias.
--    Guarda: um adiamento por DATA AGENDADA. Depois de adiar, e preciso
--    reagendar para uma nova data antes de poder adiar de novo — que e o
--    espirito da regra ("choveu no dia do jogo, adia").
--
-- 2) Limpeza: 121 reservas continuam 'confirmed' com o desafio ja encerrado
--    (heranca do cancelamento silenciosamente barrado pela RLS, corrigido na
--    049/050). Nenhuma e futura, entao nao bloqueia quadra — mas infla o
--    numero de reservas ativas do painel admin.
--
-- 3) Seguranca: expire_pending_challenges() e SECURITY DEFINER e estava
--    executavel por PUBLIC — ou seja, qualquer um com a chave anon (que vai
--    embutida no app web) conseguia disparar WO e mexer no ranking. Passa a
--    exigir usuario autenticado.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

-- 1. Marca de qual data agendada ja usou adiamento por chuva ---------------
ALTER TABLE challenges
  ADD COLUMN IF NOT EXISTS weather_extended_for timestamptz;

COMMENT ON COLUMN challenges.weather_extended_for IS
  'chosen_date que ja consumiu um adiamento por chuva. Novo adiamento so depois de reagendar.';

-- Desafios que ja tem extensao ficam marcados com a data atual, para nao
-- permitirem mais um adiamento sem reagendar.
UPDATE challenges
SET weather_extended_for = chosen_date
WHERE weather_extension_days > 0
  AND chosen_date IS NOT NULL
  AND weather_extended_for IS NULL;

-- 2. Limpeza das reservas de desafio ja encerrado --------------------------
UPDATE court_reservations cr
SET status = 'cancelled',
    updated_at = now(),
    notes = coalesce(cr.notes || ' | ', '') || 'cancelada na limpeza 051 (desafio ja encerrado)'
FROM challenges c
WHERE c.id = cr.challenge_id
  AND cr.status = 'confirmed'
  AND c.status IN ('cancelled', 'expired', 'annulled', 'completed',
                   'wo_challenger', 'wo_challenged');

-- 3. expire_pending_challenges so para usuario autenticado -----------------
REVOKE EXECUTE ON FUNCTION expire_pending_challenges() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION expire_pending_challenges() FROM anon;
GRANT EXECUTE ON FUNCTION expire_pending_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION expire_pending_challenges() TO service_role;
