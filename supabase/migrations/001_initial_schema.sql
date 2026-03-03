-- ============================================================
-- SmashRank - Initial Schema
-- ============================================================

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
