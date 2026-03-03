-- ============================================================
-- SmashRank - SETUP COMPLETO
-- Execute este arquivo inteiro no SQL Editor do Supabase
-- ============================================================

-- ************************************************************
-- PARTE 1: SCHEMA (Tabelas, Indexes, Triggers)
-- ************************************************************

-- ENUM TYPES
CREATE TYPE player_status AS ENUM ('active', 'inactive', 'ambulance', 'suspended');
CREATE TYPE player_role AS ENUM ('player', 'admin');
CREATE TYPE challenge_status AS ENUM (
  'pending', 'dates_proposed', 'scheduled', 'completed',
  'wo_challenger', 'wo_challenged', 'expired', 'cancelled'
);
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'overdue');
CREATE TYPE reservation_status AS ENUM ('confirmed', 'cancelled');
CREATE TYPE notification_type AS ENUM (
  'challenge_received', 'dates_proposed', 'date_chosen',
  'match_result', 'ranking_change', 'ambulance_activated',
  'ambulance_expired', 'payment_due', 'payment_overdue',
  'wo_warning', 'monthly_challenge_warning', 'general'
);

-- PLAYERS TABLE
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  nickname TEXT,
  email TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  date_of_birth DATE,
  role player_role NOT NULL DEFAULT 'player',
  status player_status NOT NULL DEFAULT 'active',
  ranking_position INT,
  challenges_this_month INT NOT NULL DEFAULT 0,
  last_challenge_date TIMESTAMPTZ,
  challenger_cooldown_until TIMESTAMPTZ,
  challenged_protection_until TIMESTAMPTZ,
  ambulance_active BOOLEAN NOT NULL DEFAULT FALSE,
  ambulance_started_at TIMESTAMPTZ,
  ambulance_protection_until TIMESTAMPTZ,
  must_be_challenged_first BOOLEAN NOT NULL DEFAULT FALSE,
  fee_status payment_status NOT NULL DEFAULT 'pending',
  fee_due_date DATE,
  fee_overdue_since DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_players_auth_id ON players(auth_id);
CREATE INDEX idx_players_ranking ON players(ranking_position);
CREATE INDEX idx_players_status ON players(status);
CREATE INDEX idx_players_fee_status ON players(fee_status);

-- RANKING_HISTORY TABLE
CREATE TABLE ranking_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  old_position INT,
  new_position INT NOT NULL,
  reason TEXT NOT NULL,
  reference_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ranking_history_player ON ranking_history(player_id);
CREATE INDEX idx_ranking_history_date ON ranking_history(created_at);

-- CHALLENGES TABLE
CREATE TABLE challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID NOT NULL REFERENCES players(id),
  challenged_id UUID NOT NULL REFERENCES players(id),
  status challenge_status NOT NULL DEFAULT 'pending',
  challenger_position INT NOT NULL,
  challenged_position INT NOT NULL,
  proposed_date_1 TIMESTAMPTZ,
  proposed_date_2 TIMESTAMPTZ,
  proposed_date_3 TIMESTAMPTZ,
  chosen_date TIMESTAMPTZ,
  weather_extension_days INT NOT NULL DEFAULT 0,
  play_deadline TIMESTAMPTZ,
  winner_id UUID REFERENCES players(id),
  loser_id UUID REFERENCES players(id),
  wo_player_id UUID REFERENCES players(id),
  challenged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  response_deadline TIMESTAMPTZ,
  dates_proposed_at TIMESTAMPTZ,
  date_chosen_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_different_players CHECK (challenger_id != challenged_id)
);

CREATE INDEX idx_challenges_challenger ON challenges(challenger_id);
CREATE INDEX idx_challenges_challenged ON challenges(challenged_id);
CREATE INDEX idx_challenges_status ON challenges(status);
CREATE INDEX idx_challenges_response_deadline ON challenges(response_deadline) WHERE status = 'pending';
CREATE INDEX idx_challenges_play_deadline ON challenges(play_deadline) WHERE status = 'scheduled';

-- MATCHES TABLE
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  winner_id UUID NOT NULL REFERENCES players(id),
  loser_id UUID NOT NULL REFERENCES players(id),
  sets JSONB NOT NULL DEFAULT '[]',
  winner_sets INT NOT NULL,
  loser_sets INT NOT NULL,
  super_tiebreak BOOLEAN NOT NULL DEFAULT FALSE,
  played_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_matches_challenge ON matches(challenge_id);
CREATE INDEX idx_matches_winner ON matches(winner_id);
CREATE INDEX idx_matches_loser ON matches(loser_id);
CREATE INDEX idx_matches_played_at ON matches(played_at);

-- AMBULANCES TABLE
CREATE TABLE ambulances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id),
  reason TEXT NOT NULL,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  position_at_activation INT NOT NULL,
  initial_penalty_applied BOOLEAN NOT NULL DEFAULT FALSE,
  protection_ends_at TIMESTAMPTZ,
  deactivated_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  daily_penalties_applied INT NOT NULL DEFAULT 0,
  last_daily_penalty_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ambulances_player ON ambulances(player_id);
CREATE INDEX idx_ambulances_active ON ambulances(is_active) WHERE is_active = TRUE;

-- COURTS TABLE
CREATE TABLE courts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  surface_type TEXT,
  is_covered BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- COURT_SLOTS TABLE
CREATE TABLE court_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  court_id UUID NOT NULL REFERENCES courts(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_slot_times CHECK (end_time > start_time),
  CONSTRAINT uq_court_slot UNIQUE (court_id, day_of_week, start_time)
);

CREATE INDEX idx_court_slots_court ON court_slots(court_id);
CREATE INDEX idx_court_slots_day ON court_slots(day_of_week);

-- COURT_RESERVATIONS TABLE
CREATE TABLE court_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  court_slot_id UUID NOT NULL REFERENCES court_slots(id),
  court_id UUID NOT NULL REFERENCES courts(id),
  reserved_by UUID NOT NULL REFERENCES players(id),
  reservation_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status reservation_status NOT NULL DEFAULT 'confirmed',
  challenge_id UUID REFERENCES challenges(id),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reservation UNIQUE (court_id, reservation_date, start_time)
);

CREATE INDEX idx_reservations_date ON court_reservations(reservation_date);
CREATE INDEX idx_reservations_player ON court_reservations(reserved_by);
CREATE INDEX idx_reservations_court ON court_reservations(court_id);
CREATE INDEX idx_reservations_challenge ON court_reservations(challenge_id);

-- NOTIFICATIONS TABLE
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_player ON notifications(player_id);
CREATE INDEX idx_notifications_unread ON notifications(player_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_date ON notifications(created_at);

-- MONTHLY_FEES TABLE
CREATE TABLE monthly_fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  reference_month DATE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  due_date DATE NOT NULL,
  paid_at TIMESTAMPTZ,
  payment_method TEXT,
  receipt_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_fee_per_month UNIQUE (player_id, reference_month)
);

CREATE INDEX idx_fees_player ON monthly_fees(player_id);
CREATE INDEX idx_fees_status ON monthly_fees(status);
CREATE INDEX idx_fees_due_date ON monthly_fees(due_date);

-- WHATSAPP_LOGS TABLE
CREATE TABLE whatsapp_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID REFERENCES players(id),
  phone TEXT NOT NULL,
  message_type TEXT NOT NULL,
  message_body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  external_id TEXT,
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_whatsapp_player ON whatsapp_logs(player_id);
CREATE INDEX idx_whatsapp_status ON whatsapp_logs(status);

-- UPDATED_AT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_players_updated_at BEFORE UPDATE ON players FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_challenges_updated_at BEFORE UPDATE ON challenges FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_ambulances_updated_at BEFORE UPDATE ON ambulances FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_courts_updated_at BEFORE UPDATE ON courts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_reservations_updated_at BEFORE UPDATE ON court_reservations FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_fees_updated_at BEFORE UPDATE ON monthly_fees FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ************************************************************
-- PARTE 2: ROW LEVEL SECURITY (RLS Policies)
-- ************************************************************

-- Helper functions
CREATE OR REPLACE FUNCTION get_player_role()
RETURNS player_role AS $$
  SELECT role FROM players WHERE auth_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM players WHERE auth_id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_player_id()
RETURNS UUID AS $$
  SELECT id FROM players WHERE auth_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- PLAYERS
ALTER TABLE players ENABLE ROW LEVEL SECURITY;

CREATE POLICY players_select ON players
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY players_insert ON players
  FOR INSERT TO authenticated
  WITH CHECK (auth_id = auth.uid() OR is_admin());

CREATE POLICY players_update_own ON players
  FOR UPDATE TO authenticated
  USING (auth_id = auth.uid());

CREATE POLICY players_admin_update ON players
  FOR UPDATE TO authenticated
  USING (is_admin());

-- RANKING_HISTORY
ALTER TABLE ranking_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY ranking_history_select ON ranking_history
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY ranking_history_admin_insert ON ranking_history
  FOR INSERT TO authenticated
  WITH CHECK (is_admin());

-- CHALLENGES
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenges_select ON challenges
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY challenges_insert ON challenges
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() OR challenger_id = get_player_id());

CREATE POLICY challenges_update ON challenges
  FOR UPDATE TO authenticated
  USING (
    challenger_id = get_player_id()
    OR challenged_id = get_player_id()
    OR is_admin()
  );

-- MATCHES
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

CREATE POLICY matches_select ON matches
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY matches_insert ON matches
  FOR INSERT TO authenticated
  WITH CHECK (
    winner_id = get_player_id()
    OR loser_id = get_player_id()
    OR is_admin()
  );

-- AMBULANCES
ALTER TABLE ambulances ENABLE ROW LEVEL SECURITY;

CREATE POLICY ambulances_select ON ambulances
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY ambulances_insert ON ambulances
  FOR INSERT TO authenticated
  WITH CHECK (is_admin());

CREATE POLICY ambulances_update ON ambulances
  FOR UPDATE TO authenticated
  USING (is_admin());

-- COURTS
ALTER TABLE courts ENABLE ROW LEVEL SECURITY;

CREATE POLICY courts_select ON courts
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY courts_admin ON courts
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- COURT_SLOTS
ALTER TABLE court_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY court_slots_select ON court_slots
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY court_slots_admin ON court_slots
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- COURT_RESERVATIONS
ALTER TABLE court_reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY reservations_select ON court_reservations
  FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY reservations_insert ON court_reservations
  FOR INSERT TO authenticated
  WITH CHECK (reserved_by = get_player_id() OR is_admin());

CREATE POLICY reservations_update ON court_reservations
  FOR UPDATE TO authenticated
  USING (reserved_by = get_player_id() OR is_admin());

CREATE POLICY reservations_delete ON court_reservations
  FOR DELETE TO authenticated
  USING (reserved_by = get_player_id() OR is_admin());

-- NOTIFICATIONS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select ON notifications
  FOR SELECT TO authenticated
  USING (player_id = get_player_id());

CREATE POLICY notifications_update ON notifications
  FOR UPDATE TO authenticated
  USING (player_id = get_player_id())
  WITH CHECK (player_id = get_player_id());

CREATE POLICY notifications_insert ON notifications
  FOR INSERT TO authenticated
  WITH CHECK (
    is_admin()
    OR player_id != get_player_id()
  );

-- MONTHLY_FEES
ALTER TABLE monthly_fees ENABLE ROW LEVEL SECURITY;

CREATE POLICY fees_select ON monthly_fees
  FOR SELECT TO authenticated
  USING (player_id = get_player_id() OR is_admin());

CREATE POLICY fees_admin ON monthly_fees
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- WHATSAPP_LOGS
ALTER TABLE whatsapp_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY whatsapp_admin ON whatsapp_logs
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());


-- ************************************************************
-- PARTE 3: DATABASE FUNCTIONS (Logica de Negocio)
-- ************************************************************

-- FUNCTION: swap_ranking_after_challenge
-- When challenger wins: takes loser's position, loser drops 1
-- When challenged wins: no position change
CREATE OR REPLACE FUNCTION swap_ranking_after_challenge(
  p_challenge_id UUID,
  p_winner_id UUID,
  p_loser_id UUID,
  p_sets JSONB,
  p_winner_sets INT,
  p_loser_sets INT,
  p_super_tiebreak BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_challenger_id UUID;
  v_challenged_id UUID;
  v_winner_pos INT;
  v_loser_pos INT;
  v_challenge RECORD;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found: %', p_challenge_id;
  END IF;
  IF v_challenge.status NOT IN ('scheduled', 'wo_challenged') THEN
    RAISE EXCEPTION 'Challenge is not in valid status: %', v_challenge.status;
  END IF;

  v_challenger_id := v_challenge.challenger_id;
  v_challenged_id := v_challenge.challenged_id;

  SELECT ranking_position INTO v_winner_pos FROM players WHERE id = p_winner_id;
  SELECT ranking_position INTO v_loser_pos FROM players WHERE id = p_loser_id;

  -- Record match
  INSERT INTO matches (challenge_id, winner_id, loser_id, sets, winner_sets, loser_sets, super_tiebreak)
  VALUES (p_challenge_id, p_winner_id, p_loser_id, p_sets, p_winner_sets, p_loser_sets, p_super_tiebreak);

  -- Only swap if challenger won AND challenger was below (higher number)
  IF p_winner_id = v_challenger_id AND v_winner_pos > v_loser_pos THEN
    UPDATE players SET ranking_position = v_loser_pos WHERE id = p_winner_id;
    UPDATE players SET ranking_position = v_loser_pos + 1 WHERE id = p_loser_id;

    -- Push everyone between old positions down by 1
    UPDATE players
    SET ranking_position = ranking_position + 1
    WHERE ranking_position > v_loser_pos
      AND ranking_position < v_winner_pos
      AND id != p_winner_id
      AND id != p_loser_id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
    VALUES (p_winner_id, v_winner_pos, v_loser_pos, 'challenge_win', p_challenge_id);
    INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
    VALUES (p_loser_id, v_loser_pos, v_loser_pos + 1, 'challenge_loss', p_challenge_id);

    -- Notification: ranking_change for winner
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      p_winner_id, 'ranking_change', 'Ranking Atualizado!',
      format('Voce subiu para a posicao #%s (era #%s).', v_loser_pos, v_winner_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_winner_pos, 'new_position', v_loser_pos)
    );

    -- Notification: ranking_change for loser
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      p_loser_id, 'ranking_change', 'Ranking Atualizado',
      format('Voce desceu para a posicao #%s (era #%s).', v_loser_pos + 1, v_loser_pos),
      jsonb_build_object('challenge_id', p_challenge_id, 'old_position', v_loser_pos, 'new_position', v_loser_pos + 1)
    );
  END IF;

  -- Update challenge status
  UPDATE challenges
  SET status = 'completed',
      winner_id = p_winner_id,
      loser_id = p_loser_id,
      completed_at = now()
  WHERE id = p_challenge_id;

  -- Set cooldowns
  UPDATE players
  SET challenger_cooldown_until = now() + INTERVAL '48 hours',
      last_challenge_date = now(),
      challenges_this_month = challenges_this_month + 1
  WHERE id = v_challenger_id;

  UPDATE players
  SET challenged_protection_until = now() + INTERVAL '24 hours'
  WHERE id = v_challenged_id;

  -- Notification: match_result for winner
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_winner_id, 'match_result', 'Resultado Registrado',
    'Voce venceu o desafio! Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id)
  );

  -- Notification: match_result for loser
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_loser_id, 'match_result', 'Resultado Registrado',
    'O resultado do seu desafio foi registrado. Confira os detalhes.',
    jsonb_build_object('challenge_id', p_challenge_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: activate_ambulance
-- -3 positions immediately, 10 days protection
CREATE OR REPLACE FUNCTION activate_ambulance(
  p_player_id UUID,
  p_reason TEXT
)
RETURNS UUID AS $$
DECLARE
  v_current_pos INT;
  v_new_pos INT;
  v_max_pos INT;
  v_ambulance_id UUID;
BEGIN
  SELECT ranking_position INTO v_current_pos FROM players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found: %', p_player_id;
  END IF;

  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';
  v_new_pos := LEAST(v_current_pos + 3, v_max_pos);

  -- Shift players between old+1 and new up by 1
  UPDATE players
  SET ranking_position = ranking_position - 1
  WHERE ranking_position > v_current_pos
    AND ranking_position <= v_new_pos
    AND id != p_player_id;

  UPDATE players
  SET ranking_position = v_new_pos,
      status = 'ambulance',
      ambulance_active = TRUE,
      ambulance_started_at = now(),
      ambulance_protection_until = now() + INTERVAL '10 days',
      must_be_challenged_first = TRUE
  WHERE id = p_player_id;

  INSERT INTO ambulances (player_id, reason, position_at_activation, initial_penalty_applied, protection_ends_at)
  VALUES (p_player_id, p_reason, v_current_pos, TRUE, now() + INTERVAL '10 days')
  RETURNING id INTO v_ambulance_id;

  INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
  VALUES (p_player_id, v_current_pos, v_new_pos, 'ambulance_penalty', v_ambulance_id);

  -- Notification: ambulance_activated
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_player_id, 'ambulance_activated', 'Ambulancia Ativada',
    format('Ambulancia ativada. Voce foi para a posicao #%s (era #%s). Protecao de 10 dias ativa.', v_new_pos, v_current_pos),
    jsonb_build_object('ambulance_id', v_ambulance_id, 'reason', p_reason, 'old_position', v_current_pos, 'new_position', v_new_pos)
  );

  RETURN v_ambulance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: deactivate_ambulance
CREATE OR REPLACE FUNCTION deactivate_ambulance(p_player_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE ambulances
  SET is_active = FALSE, deactivated_at = now()
  WHERE player_id = p_player_id AND is_active = TRUE;

  UPDATE players
  SET status = 'active',
      ambulance_active = FALSE,
      ambulance_started_at = NULL,
      ambulance_protection_until = NULL
  WHERE id = p_player_id;

  -- Notification: ambulance_expired
  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_player_id, 'ambulance_expired', 'Ambulancia Desativada',
    'Sua ambulancia foi desativada. Voce esta de volta ao ranking ativo.',
    jsonb_build_object()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: apply_ambulance_daily_penalties
-- Called by cron: -1 position per day after protection ends
CREATE OR REPLACE FUNCTION apply_ambulance_daily_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_ambulance RECORD;
  v_current_pos INT;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_ambulance IN
    SELECT a.*, p.ranking_position
    FROM ambulances a
    JOIN players p ON p.id = a.player_id
    WHERE a.is_active = TRUE
      AND a.protection_ends_at < now()
      AND (a.last_daily_penalty_at IS NULL
           OR a.last_daily_penalty_at < now() - INTERVAL '1 day')
  LOOP
    v_current_pos := v_ambulance.ranking_position;
    IF v_current_pos < v_max_pos THEN
      UPDATE players
      SET ranking_position = ranking_position - 1
      WHERE ranking_position = v_current_pos + 1
        AND id != v_ambulance.player_id;

      UPDATE players
      SET ranking_position = v_current_pos + 1
      WHERE id = v_ambulance.player_id;

      UPDATE ambulances
      SET daily_penalties_applied = daily_penalties_applied + 1,
          last_daily_penalty_at = now()
      WHERE id = v_ambulance.id;

      INSERT INTO ranking_history (player_id, old_position, new_position, reason, reference_id)
      VALUES (v_ambulance.player_id, v_current_pos, v_current_pos + 1, 'ambulance_daily_penalty', v_ambulance.id);

      -- Notification: ranking_change for ambulance daily penalty
      INSERT INTO notifications (player_id, type, title, body, data)
      VALUES (
        v_ambulance.player_id, 'ranking_change', 'Penalizacao Diaria - Ambulancia',
        format('Voce perdeu 1 posicao por ambulancia ativa. Agora: #%s.', v_current_pos + 1),
        jsonb_build_object('old_position', v_current_pos, 'new_position', v_current_pos + 1)
      );

      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: apply_overdue_penalties
-- Players 15+ days overdue lose 10 positions
CREATE OR REPLACE FUNCTION apply_overdue_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_player RECORD;
  v_new_pos INT;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_player IN
    SELECT p.*
    FROM players p
    JOIN monthly_fees mf ON mf.player_id = p.id
    WHERE mf.status = 'overdue'
      AND mf.due_date + INTERVAL '15 days' <= CURRENT_DATE
      AND p.status = 'active'
      AND p.fee_status != 'overdue'
  LOOP
    v_new_pos := LEAST(v_player.ranking_position + 10, v_max_pos);

    UPDATE players
    SET ranking_position = ranking_position - 1
    WHERE ranking_position > v_player.ranking_position
      AND ranking_position <= v_new_pos
      AND id != v_player.id;

    UPDATE players
    SET ranking_position = v_new_pos,
        fee_status = 'overdue',
        fee_overdue_since = CURRENT_DATE
    WHERE id = v_player.id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason)
    VALUES (v_player.id, v_player.ranking_position, v_new_pos, 'overdue_penalty');

    -- Notification: payment_overdue
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_player.id, 'payment_overdue', 'Penalizacao por Inadimplencia',
      format('Voce perdeu %s posicoes por atraso na mensalidade (15+ dias). Regularize para evitar mais penalizacoes.', v_new_pos - v_player.ranking_position),
      jsonb_build_object('old_position', v_player.ranking_position, 'new_position', v_new_pos)
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: apply_monthly_inactivity_penalties
-- No challenge in a month = -1 position
CREATE OR REPLACE FUNCTION apply_monthly_inactivity_penalties()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_player RECORD;
  v_max_pos INT;
BEGIN
  SELECT MAX(ranking_position) INTO v_max_pos FROM players WHERE status != 'inactive';

  FOR v_player IN
    SELECT * FROM players
    WHERE status = 'active'
      AND challenges_this_month = 0
      AND ranking_position < v_max_pos
  LOOP
    UPDATE players
    SET ranking_position = ranking_position - 1
    WHERE ranking_position = v_player.ranking_position + 1
      AND id != v_player.id;

    UPDATE players
    SET ranking_position = v_player.ranking_position + 1
    WHERE id = v_player.id;

    INSERT INTO ranking_history (player_id, old_position, new_position, reason)
    VALUES (v_player.id, v_player.ranking_position, v_player.ranking_position + 1, 'monthly_inactivity');

    -- Notification: ranking_change for monthly inactivity
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_player.id, 'ranking_change', 'Penalizacao por Inatividade',
      format('Voce perdeu 1 posicao por nao ter jogado nenhum desafio este mes. Agora: #%s.', v_player.ranking_position + 1),
      jsonb_build_object('old_position', v_player.ranking_position, 'new_position', v_player.ranking_position + 1)
    );

    v_count := v_count + 1;
  END LOOP;

  UPDATE players SET challenges_this_month = 0 WHERE status != 'inactive';

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: validate_challenge_creation
-- Enforces all business rules before allowing a challenge
CREATE OR REPLACE FUNCTION validate_challenge_creation(
  p_challenger_id UUID,
  p_challenged_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_challenger RECORD;
  v_challenged RECORD;
  v_active_challenge_count INT;
BEGIN
  SELECT * INTO v_challenger FROM players WHERE id = p_challenger_id;
  SELECT * INTO v_challenged FROM players WHERE id = p_challenged_id;

  IF v_challenger.status != 'active' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador nao esta ativo');
  END IF;
  IF v_challenged.status NOT IN ('active') THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Jogador desafiado nao esta disponivel');
  END IF;

  IF v_challenger.fee_status = 'overdue' THEN
    RETURN jsonb_build_object('valid', FALSE, 'error', 'Mensalidade em atraso. Regularize para desafiar.');
  END IF;

  IF v_challenger.must_be_challenged_first THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Voce deve ser desafiado primeiro apos retornar da ambulancia');
  END IF;

  IF v_challenger.ranking_position - v_challenged.ranking_position > 2 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'So pode desafiar jogadores ate 2 posicoes a frente');
  END IF;
  IF v_challenged.ranking_position >= v_challenger.ranking_position THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'So pode desafiar jogadores acima no ranking');
  END IF;

  IF v_challenger.challenger_cooldown_until IS NOT NULL
     AND v_challenger.challenger_cooldown_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      format('Cooldown ativo ate %s', v_challenger.challenger_cooldown_until));
  END IF;

  IF v_challenged.challenged_protection_until IS NOT NULL
     AND v_challenged.challenged_protection_until > now() THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Este jogador esta protegido temporariamente');
  END IF;

  SELECT COUNT(*) INTO v_active_challenge_count
  FROM challenges
  WHERE status IN ('pending', 'dates_proposed', 'scheduled')
    AND (challenger_id = p_challenger_id OR challenged_id = p_challenger_id
         OR challenger_id = p_challenged_id OR challenged_id = p_challenged_id);

  IF v_active_challenge_count > 0 THEN
    RETURN jsonb_build_object('valid', FALSE, 'error',
      'Um dos jogadores ja possui um desafio ativo');
  END IF;

  RETURN jsonb_build_object('valid', TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: create_challenge
CREATE OR REPLACE FUNCTION create_challenge(
  p_challenger_auth_id UUID,
  p_challenged_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_challenger_id UUID;
  v_validation JSONB;
  v_challenge_id UUID;
  v_challenger_pos INT;
  v_challenged_pos INT;
BEGIN
  SELECT id INTO v_challenger_id FROM players WHERE auth_id = p_challenger_auth_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Jogador nao encontrado para auth_id: %', p_challenger_auth_id;
  END IF;

  v_validation := validate_challenge_creation(v_challenger_id, p_challenged_id);
  IF NOT (v_validation->>'valid')::BOOLEAN THEN
    RAISE EXCEPTION '%', v_validation->>'error';
  END IF;

  SELECT ranking_position INTO v_challenger_pos FROM players WHERE id = v_challenger_id;
  SELECT ranking_position INTO v_challenged_pos FROM players WHERE id = p_challenged_id;

  INSERT INTO challenges (
    challenger_id, challenged_id,
    challenger_position, challenged_position,
    response_deadline
  )
  VALUES (
    v_challenger_id, p_challenged_id,
    v_challenger_pos, v_challenged_pos,
    now() + INTERVAL '48 hours'
  )
  RETURNING id INTO v_challenge_id;

  INSERT INTO notifications (player_id, type, title, body, data)
  VALUES (
    p_challenged_id,
    'challenge_received',
    'Novo Desafio!',
    format('Voce foi desafiado pelo jogador da posicao #%s. Responda em 48h.', v_challenger_pos),
    jsonb_build_object('challenge_id', v_challenge_id)
  );

  RETURN v_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FUNCTION: expire_pending_challenges
-- Auto-expire challenges without response after 48h
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
    -- Set to 'scheduled' temporarily so swap_ranking_after_challenge works
    UPDATE challenges
    SET status = 'scheduled'
    WHERE id = v_challenge.id;

    -- Perform the ranking swap (sets status to 'completed' + sends match_result notifications)
    PERFORM swap_ranking_after_challenge(
      v_challenge.id,
      v_challenge.challenger_id,
      v_challenge.challenged_id,
      '[]'::JSONB, 0, 0, FALSE
    );

    -- Override to wo_challenged status
    UPDATE challenges
    SET status = 'wo_challenged',
        wo_player_id = v_challenge.challenged_id
    WHERE id = v_challenge.id;

    -- Notification: wo_warning for challenged player (who didn't respond)
    INSERT INTO notifications (player_id, type, title, body, data)
    VALUES (
      v_challenge.challenged_id, 'wo_warning', 'WO - Desafio Expirado',
      'Voce nao respondeu ao desafio em 48h e perdeu por WO.',
      jsonb_build_object('challenge_id', v_challenge.id)
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ************************************************************
-- PARTE 4: SEED DATA (Dados Iniciais)
-- ************************************************************

-- NOTE: Replace 'ADMIN_AUTH_UUID_HERE' with the actual UUID
-- from Supabase Auth after creating the admin user via dashboard.

-- Admin user placeholder
-- INSERT INTO players (auth_id, full_name, email, phone, role, ranking_position)
-- VALUES ('ADMIN_AUTH_UUID_HERE', 'Admin ATS', 'admin@ats.com', '+5511999999999', 'admin', 1);

-- Sample courts
INSERT INTO courts (name, surface_type, is_covered) VALUES
  ('Quadra 1', 'saibro', FALSE),
  ('Quadra 2', 'saibro', FALSE),
  ('Quadra 3', 'dura', TRUE);

-- Generate hourly slots for all courts (Monday-Saturday, 7:00-21:00)
INSERT INTO court_slots (court_id, day_of_week, start_time, end_time)
SELECT
  c.id,
  d.dow,
  (h.hour || ':00')::TIME,
  ((h.hour + 1) || ':00')::TIME
FROM courts c
CROSS JOIN generate_series(1, 6) AS d(dow)
CROSS JOIN generate_series(7, 20) AS h(hour);

-- Sunday slots (fewer hours: 8:00-18:00)
INSERT INTO court_slots (court_id, day_of_week, start_time, end_time)
SELECT
  c.id,
  0,
  (h.hour || ':00')::TIME,
  ((h.hour + 1) || ':00')::TIME
FROM courts c
CROSS JOIN generate_series(8, 17) AS h(hour);


-- ************************************************************
-- SETUP COMPLETO!
-- ************************************************************
-- Proximo passo: Crie um usuario admin pelo Supabase Auth Dashboard,
-- copie o UUID dele, e execute o INSERT do admin (descomente acima).
-- ************************************************************
