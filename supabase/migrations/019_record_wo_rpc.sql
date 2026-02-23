-- ============================================================
-- 019: RPC record_wo — Manual WO (walkover) recording
-- ============================================================
-- Allows a player to record a WO result for a scheduled challenge.
-- Reuses swap_ranking_after_challenge for ranking updates,
-- then overrides status to wo_challenger or wo_challenged.
-- ============================================================

CREATE OR REPLACE FUNCTION record_wo(
  p_challenge_id UUID,
  p_winner_id UUID,
  p_loser_id UUID
) RETURNS void AS $$
DECLARE
  v_challenge RECORD;
BEGIN
  SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Challenge not found: %', p_challenge_id;
  END IF;
  IF v_challenge.status != 'scheduled' THEN
    RAISE EXCEPTION 'Challenge is not in valid status for WO: %', v_challenge.status;
  END IF;

  -- Use swap_ranking to handle ranking swap + match insert + notifications
  PERFORM swap_ranking_after_challenge(
    p_challenge_id, p_winner_id, p_loser_id,
    '[]'::JSONB, 0, 0, FALSE
  );

  -- Override status to WO (swap_ranking sets it to 'completed', we override)
  UPDATE challenges
  SET status = CASE
    WHEN p_loser_id = v_challenge.challenger_id THEN 'wo_challenger'::challenge_status
    ELSE 'wo_challenged'::challenge_status
  END,
  wo_player_id = p_loser_id
  WHERE id = p_challenge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
