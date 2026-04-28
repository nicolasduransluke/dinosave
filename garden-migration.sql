-- ============================================
-- DINOSAVE — Garden Feature Migration
-- Run this in Supabase SQL Editor
-- Date: 2026-04-27
-- ============================================

ALTER TABLE game_saves
  ADD COLUMN IF NOT EXISTS seed_inventory     JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS garden_plots       JSONB DEFAULT '[
    {"id":0,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null},
    {"id":1,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null},
    {"id":2,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null},
    {"id":3,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null},
    {"id":4,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null},
    {"id":5,"seedId":null,"plantedAt":null,"mutation":null,"lastHitAt":null}
  ]'::jsonb,
  ADD COLUMN IF NOT EXISTS harvest_inventory  JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS seed_shop_state    JSONB DEFAULT '{"lastRestock":null,"stock":[]}'::jsonb;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'game_saves'
  AND column_name IN ('seed_inventory','garden_plots','harvest_inventory','seed_shop_state');
