-- Drop old 2-param overload that conflicts with the 3-param version from 008_sports.sql
DROP FUNCTION IF EXISTS approve_join_request(UUID, UUID);
