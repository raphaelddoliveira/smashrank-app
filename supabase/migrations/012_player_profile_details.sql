-- Add profile detail columns to players
ALTER TABLE players
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS dominant_hand TEXT CHECK (dominant_hand IN ('right', 'left')),
  ADD COLUMN IF NOT EXISTS favorite_sport_id UUID REFERENCES sports(id),
  ADD COLUMN IF NOT EXISTS backhand_type TEXT CHECK (backhand_type IN ('one_handed', 'two_handed')),
  ADD COLUMN IF NOT EXISTS preferred_surface TEXT;
