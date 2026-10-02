-- ============================================================
-- Migration 058: campos para pagar a mensalidade por PIX no app
-- ============================================================
-- O clube quer, por enquanto, apenas a POSSIBILIDADE de pagar dentro do app
-- (nada de disparo de cobranca pra ninguem). O jogador abre a mensalidade em
-- aberto, toca em pagar e recebe o PIX copia-e-cola na tela.
--
-- Para emitir PIX a Cora exige CPF/CNPJ do pagador, e hoje o cadastro de
-- jogador NAO tem esse campo. Tambem precisamos guardar, na mensalidade, qual
-- cobranca da Cora corresponde a ela — e assim nao gerar duas cobrancas para
-- a mesma mensalidade quando o jogador tocar duas vezes.
--
-- Aplicar no Supabase de PRODUCAO (azrobrhqzbuvijqpvsxn).
-- ============================================================

-- CPF do jogador (so digitos). Opcional: so quem for pagar por PIX precisa.
ALTER TABLE players
  ADD COLUMN IF NOT EXISTS document text;

COMMENT ON COLUMN players.document IS
  'CPF do jogador, so digitos. Exigido pela Cora para emitir PIX/boleto.';

-- Vinculo da mensalidade com a cobranca emitida
ALTER TABLE monthly_fees
  ADD COLUMN IF NOT EXISTS cora_invoice_id text,
  ADD COLUMN IF NOT EXISTS pix_code text,
  ADD COLUMN IF NOT EXISTS description text;

COMMENT ON COLUMN monthly_fees.cora_invoice_id IS
  'id da cobranca na Cora. Uma mensalidade tem no maximo uma cobranca ativa.';
COMMENT ON COLUMN monthly_fees.pix_code IS
  'copia e cola do PIX, guardado para reapresentar sem emitir outra cobranca.';

CREATE UNIQUE INDEX IF NOT EXISTS uniq_mensalidade_por_cobranca
  ON monthly_fees (cora_invoice_id)
  WHERE cora_invoice_id IS NOT NULL;

-- O jogador precisa enxergar e atualizar o proprio CPF; o resto da politica
-- de players ja existe e nao e tocada aqui.
