-- ============================================================
-- Regra: Bloqueio de resultado antecipado
-- Só permite registrar resultado 40 min após o horário agendado
-- ============================================================

ALTER TABLE club_sports
  ADD COLUMN IF NOT EXISTS rule_result_delay_enabled BOOLEAN NOT NULL DEFAULT true;
