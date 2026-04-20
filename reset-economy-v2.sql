-- ============================================
-- DINOSAVE — Reset total para Economy V2
-- Correr en Supabase SQL Editor
-- Fecha: 2026-04-19
-- ============================================

-- 1. Backup de seguridad (tablas paralelas en el mismo DB)
DROP TABLE IF EXISTS game_saves_backup_20260419;
DROP TABLE IF EXISTS profiles_backup_20260419;
CREATE TABLE game_saves_backup_20260419 AS SELECT * FROM game_saves;
CREATE TABLE profiles_backup_20260419 AS SELECT * FROM profiles;

-- Verificar que el backup quedó
SELECT COUNT(*) AS saves_backed_up FROM game_saves_backup_20260419;
SELECT COUNT(*) AS profiles_backed_up FROM profiles_backup_20260419;

-- 2. Reset de todos los saves a defaults
UPDATE game_saves SET
  coins = 100,
  dna = 0,
  farm_dinos = '[]'::jsonb,
  unlocked_secrets = '[]'::jsonb,
  egg_inventory = '[]'::jsonb,
  incubators = '[{"id":1,"state":"empty"},{"id":2,"state":"empty"},{"id":3,"state":"locked"},{"id":4,"state":"locked"}]'::jsonb,
  stats = '{"totalCaught":0,"totalHatched":0,"totalConverted":0,"totalSold":0,"farmVisits":0}'::jsonb,
  updated_at = now();

-- 3. Limpiar estado de economía pública (market/trades/torneos)
TRUNCATE TABLE market_listings CASCADE;
TRUNCATE TABLE trades CASCADE;
TRUNCATE TABLE tournament_scores CASCADE;

-- Nota: amistades y mensajes se conservan (no son economía)

-- 4. Verificación final
SELECT
  (SELECT COUNT(*) FROM game_saves WHERE coins = 100 AND dna = 0) AS saves_reset,
  (SELECT COUNT(*) FROM market_listings) AS market_rows,
  (SELECT COUNT(*) FROM trades) AS trade_rows,
  (SELECT COUNT(*) FROM tournament_scores) AS tournament_rows;

-- Si algo salió mal, rollback:
-- DELETE FROM game_saves;
-- INSERT INTO game_saves SELECT * FROM game_saves_backup_20260419;
