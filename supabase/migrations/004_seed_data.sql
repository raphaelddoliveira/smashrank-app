-- ============================================================
-- SmashRank - Seed Data
-- ============================================================

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
