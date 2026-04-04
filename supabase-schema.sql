-- ============================================
-- DINOSAVE — Supabase Database Schema
-- Run this in your Supabase SQL Editor:
-- supabase.com → Your Project → SQL Editor → New Query → Paste & Run
-- ============================================

-- 1. PROFILES (linked to auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  avatar TEXT DEFAULT '🦖',
  created_at TIMESTAMPTZ DEFAULT now(),
  last_seen TIMESTAMPTZ DEFAULT now(),
  is_online BOOLEAN DEFAULT false
);

-- 2. GAME SAVES (one per user)
CREATE TABLE IF NOT EXISTS game_saves (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  coins BIGINT DEFAULT 100,
  dna BIGINT DEFAULT 0,
  farm_dinos JSONB DEFAULT '[]'::jsonb,
  unlocked_secrets JSONB DEFAULT '[]'::jsonb,
  egg_inventory JSONB DEFAULT '[]'::jsonb,
  incubators JSONB DEFAULT '[{"id":1,"state":"empty"},{"id":2,"state":"empty"},{"id":3,"state":"locked"},{"id":4,"state":"locked"}]'::jsonb,
  stats JSONB DEFAULT '{"totalCaught":0,"totalHatched":0,"totalConverted":0,"totalSold":0,"farmVisits":0}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. FRIENDS
CREATE TABLE IF NOT EXISTS friends (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, friend_id)
);

-- 4. MESSAGES
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. TRADES
CREATE TABLE IF NOT EXISTS trades (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  from_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  to_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  offer_dino TEXT NOT NULL,
  want_dino TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. MARKET LISTINGS
CREATE TABLE IF NOT EXISTS market_listings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('dino','dna','egg')),
  item_name TEXT NOT NULL,
  item_emoji TEXT DEFAULT '🦕',
  item_rarity TEXT DEFAULT 'Common',
  price BIGINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. TOURNAMENT SCORES
CREATE TABLE IF NOT EXISTS tournament_scores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  avatar TEXT DEFAULT '🦖',
  dna_earned BIGINT DEFAULT 0,
  tournament_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, tournament_id)
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_scores ENABLE ROW LEVEL SECURITY;

-- PROFILES: everyone can read, only own profile can update
CREATE POLICY "Public profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- GAME SAVES: only own save
CREATE POLICY "Users can read own save" ON game_saves FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own save" ON game_saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own save" ON game_saves FOR UPDATE USING (auth.uid() = user_id);

-- FRIENDS: can see own friendships
CREATE POLICY "Users can see own friends" ON friends FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can send friend requests" ON friends FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update friend status" ON friends FOR UPDATE USING (auth.uid() = friend_id OR auth.uid() = user_id);
CREATE POLICY "Users can delete own friendships" ON friends FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- MESSAGES: can see own messages
CREATE POLICY "Users can see own messages" ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users can send messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users can update own received messages" ON messages FOR UPDATE USING (auth.uid() = receiver_id);

-- TRADES: can see trades involving self
CREATE POLICY "Users can see own trades" ON trades FOR SELECT USING (auth.uid() = from_id OR auth.uid() = to_id);
CREATE POLICY "Users can create trades" ON trades FOR INSERT WITH CHECK (auth.uid() = from_id);
CREATE POLICY "Users can update trades" ON trades FOR UPDATE USING (auth.uid() = from_id OR auth.uid() = to_id);

-- MARKET: everyone can see listings, only own can manage
CREATE POLICY "Anyone can see market" ON market_listings FOR SELECT USING (true);
CREATE POLICY "Users can list items" ON market_listings FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "Users can remove own listings" ON market_listings FOR DELETE USING (auth.uid() = seller_id);

-- TOURNAMENT: everyone can see, own can update
CREATE POLICY "Anyone can see tournament" ON tournament_scores FOR SELECT USING (true);
CREATE POLICY "Users can join tournament" ON tournament_scores FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own score" ON tournament_scores FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- REALTIME (enable for live features)
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE trades;
ALTER PUBLICATION supabase_realtime ADD TABLE market_listings;
ALTER PUBLICATION supabase_realtime ADD TABLE tournament_scores;
ALTER PUBLICATION supabase_realtime ADD TABLE friends;

-- ============================================
-- FUNCTION: Auto-create profile on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, avatar)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    '🦖'
  );
  INSERT INTO public.game_saves (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: run after new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
