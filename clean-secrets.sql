-- Limpia los unlocked_secrets contaminados en todos los saves
-- (por autosave que corrió antes del loadGameState fix)
UPDATE game_saves SET unlocked_secrets = '[]'::jsonb;

-- Verificar
SELECT user_id, unlocked_secrets FROM game_saves;
