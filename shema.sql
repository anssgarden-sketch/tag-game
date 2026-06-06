cat > /workspaces/tag-game/database/schema.sql << 'EOF'
-- ============================================================
-- TAG: The Assassination Game
-- Database Schema v1
-- ============================================================

-- ============================================================
-- ACCOUNTS
-- One account per player. Survives character death.
-- Gold coins and real-money items are stored at account level.
-- ============================================================
CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  dark_web_handle TEXT UNIQUE NOT NULL,
  swiss_bank_number TEXT UNIQUE NOT NULL,
  gold_coins INTEGER NOT NULL DEFAULT 0,
  death_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

-- ============================================================
-- PROFESSIONS
-- Seed data. Defines weekly income and AP modifier.
-- ============================================================
CREATE TABLE professions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  credits_per_week INTEGER NOT NULL DEFAULT 0,
  ap_modifier INTEGER NOT NULL DEFAULT 0,
  required_skill_id UUID, -- FK added after skills table
  schedule_type TEXT NOT NULL DEFAULT 'full_time',
  -- schedule_type: full_time | part_time | freelance | unemployed
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SKILLS
-- Master list. Shared across all skill categories.
-- ============================================================
CREATE TABLE skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  -- category: assassination | defensive | intel | counter_intel
  range TEXT NOT NULL DEFAULT 'city',
  -- assassination range: close | short | medium | long | remote
  -- intel range: city | country | continent | global
  base_ap_cost INTEGER NOT NULL DEFAULT 1,
  base_credit_cost INTEGER NOT NULL DEFAULT 0,
  required_item_id UUID, -- FK added after items table
  can_execute_in_transit BOOLEAN NOT NULL DEFAULT FALSE,
  -- only true for remote assassination skills
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ITEMS
-- Master item templates. Instances stored in inventory.
-- ============================================================
CREATE TABLE item_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  -- category: weapon | gear | consumable | document | device
  credit_cost INTEGER NOT NULL DEFAULT 0,
  gold_coin_cost INTEGER NOT NULL DEFAULT 0,
  max_uses INTEGER, -- NULL = unlimited
  is_transferable BOOLEAN NOT NULL DEFAULT TRUE,
  is_account_level BOOLEAN NOT NULL DEFAULT FALSE,
  -- true = survives character death (real-money or achievement items)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CITIES
-- Global map nodes. Coordinates are pixel positions on map image.
-- ============================================================
CREATE TABLE cities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  country TEXT NOT NULL,
  continent TEXT NOT NULL,
  map_x INTEGER NOT NULL,
  map_y INTEGER NOT NULL,
  has_airport BOOLEAN NOT NULL DEFAULT FALSE,
  has_rail BOOLEAN NOT NULL DEFAULT FALSE,
  has_port BOOLEAN NOT NULL DEFAULT FALSE,
  -- all land cities have road by default
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSPORT MODES
-- Cost rates per 100 pixels. Tunable without code changes.
-- ============================================================
CREATE TABLE transport_modes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  -- air | rail | water | road
  ap_per_100px NUMERIC NOT NULL,
  credits_per_100px NUMERIC NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- RAIL CONNECTIONS
-- Explicit city pairs with rail links.
-- ============================================================
CREATE TABLE rail_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_a_id UUID NOT NULL REFERENCES cities(id),
  city_b_id UUID NOT NULL REFERENCES cities(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(city_a_id, city_b_id)
);

-- ============================================================
-- WATER ROUTES
-- Explicit port-to-port connections.
-- ============================================================
CREATE TABLE water_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_a_id UUID NOT NULL REFERENCES cities(id),
  city_b_id UUID NOT NULL REFERENCES cities(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(city_a_id, city_b_id)
);

-- ============================================================
-- CHARACTERS
-- One active character per account at a time.
-- Permadeath: is_alive = false triggers death screen.
-- ============================================================
CREATE TABLE characters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id),
  name TEXT NOT NULL,
  is_alive BOOLEAN NOT NULL DEFAULT TRUE,
  credits INTEGER NOT NULL DEFAULT 500,
  current_city_id UUID REFERENCES cities(id),
  profession_id UUID REFERENCES professions(id),

  -- travel state
  travel_status TEXT NOT NULL DEFAULT 'arrived',
  -- arrived | in_transit
  destination_city_id UUID REFERENCES cities(id),
  transport_mode TEXT,
  journey_started_at TIMESTAMPTZ,
  arrives_at TIMESTAMPTZ,
  ap_committed INTEGER NOT NULL DEFAULT 0,

  -- death state
  killed_by_account_id UUID REFERENCES accounts(id),
  killed_with_skill_id UUID REFERENCES skills(id),
  killed_in_city_id UUID REFERENCES cities(id),
  killed_at TIMESTAMPTZ,

  -- behavior tracking for role emergence
  kill_count INTEGER NOT NULL DEFAULT 0,
  intel_sold_count INTEGER NOT NULL DEFAULT 0,
  items_sold_count INTEGER NOT NULL DEFAULT 0,
  survival_days INTEGER NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ
);

-- ============================================================
-- CHARACTER SKILLS
-- Skills selected during character creation.
-- ============================================================
CREATE TABLE character_skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id UUID NOT NULL REFERENCES characters(id),
  skill_id UUID NOT NULL REFERENCES skills(id),
  pool TEXT NOT NULL,
  -- pool: assassination | defensive | intel | counter_intel
  learned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(character_id, skill_id, pool)
);

-- ============================================================
-- ACTION POINTS
-- Tracked per character. Regenerate 1/hr real time.
-- ============================================================
CREATE TABLE action_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id UUID UNIQUE NOT NULL REFERENCES characters(id),
  current_ap INTEGER NOT NULL DEFAULT 4,
  max_ap INTEGER NOT NULL DEFAULT 4,
  -- max_ap = 4 + profession ap_modifier
  last_regen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INVENTORY
-- Item instances owned by a character.
-- ============================================================
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id UUID NOT NULL REFERENCES characters(id),
  item_template_id UUID NOT NULL REFERENCES item_templates(id),
  quantity INTEGER NOT NULL DEFAULT 1,
  uses_remaining INTEGER,
  -- NULL = unlimited use item
  is_account_level BOOLEAN NOT NULL DEFAULT FALSE,
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TAGS
-- Active assassination tags. One attacker per target at a time.
-- ============================================================
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attacker_character_id UUID NOT NULL REFERENCES characters(id),
  target_character_id UUID NOT NULL REFERENCES characters(id),
  tagged_in_city_id UUID NOT NULL REFERENCES cities(id),
  tagged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  -- tagged_at + 48 hours
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  intel_skill_used_id UUID NOT NULL REFERENCES skills(id),
  UNIQUE(attacker_character_id, target_character_id, is_active)
);

-- ============================================================
-- ASSASSINATION ATTEMPTS
-- Full log of every attempt. Never deleted.
-- ============================================================
CREATE TABLE assassination_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attacker_character_id UUID NOT NULL REFERENCES characters(id),
  target_character_id UUID NOT NULL REFERENCES characters(id),
  skill_id UUID NOT NULL REFERENCES skills(id),
  city_id UUID NOT NULL REFERENCES cities(id),
  tag_id UUID REFERENCES tags(id),
  outcome TEXT NOT NULL,
  -- outcome: killed | survived | counter_attacked | tag_expired
  ap_spent INTEGER NOT NULL DEFAULT 0,
  credits_spent INTEGER NOT NULL DEFAULT 0,
  was_queued BOOLEAN NOT NULL DEFAULT FALSE,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- GAME CONFIG
-- Tunable values. Change without code deployment.
-- ============================================================
CREATE TABLE game_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DARK WEB: MESSAGES
-- Direct messages between handles.
-- ============================================================
CREATE TABLE dw_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_account_id UUID NOT NULL REFERENCES accounts(id),
  to_account_id UUID NOT NULL REFERENCES accounts(id),
  room_id UUID,
  content TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DARK WEB: CHAT ROOMS
-- Private invite-only rooms.
-- ============================================================
CREATE TABLE dw_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  created_by_account_id UUID NOT NULL REFERENCES accounts(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE dw_room_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES dw_rooms(id),
  account_id UUID NOT NULL REFERENCES accounts(id),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(room_id, account_id)
);

-- ============================================================
-- DARK WEB: NPC MISSIONS
-- Posted by fictional organizations. Guaranteed payout.
-- ============================================================
CREATE TABLE npc_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_name TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  target_character_id UUID REFERENCES characters(id),
  target_city_id UUID REFERENCES cities(id),
  reward_credits INTEGER NOT NULL DEFAULT 0,
  reward_gold_coins INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open',
  -- open | completed | expired
  expires_at TIMESTAMPTZ,
  completed_by_account_id UUID REFERENCES accounts(id),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DARK WEB: PLAYER CONTRACTS
-- Trust-based. Optional escrow.
-- ============================================================
CREATE TABLE player_contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poster_account_id UUID NOT NULL REFERENCES accounts(id),
  target_character_id UUID REFERENCES characters(id),
  description TEXT,
  reward_credits INTEGER NOT NULL DEFAULT 0,
  reward_gold_coins INTEGER NOT NULL DEFAULT 0,
  is_escrowed BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'open',
  -- open | completed | expired | cancelled
  expires_at TIMESTAMPTZ,
  completed_by_account_id UUID REFERENCES accounts(id),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DARK WEB: MARKETPLACE LISTINGS
-- Buy and sell items and intel.
-- ============================================================
CREATE TABLE dw_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_account_id UUID NOT NULL REFERENCES accounts(id),
  listing_type TEXT NOT NULL,
  -- item | intel
  item_template_id UUID REFERENCES item_templates(id),
  intel_description TEXT,
  quantity INTEGER NOT NULL DEFAULT 1,
  price_credits INTEGER NOT NULL DEFAULT 0,
  price_gold_coins INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  -- active | sold | cancelled
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TICKER TAPE
-- Anonymized world events. Public feed.
-- ============================================================
CREATE TABLE ticker_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  -- body_found | contract_completed | mission_completed
  city_id UUID REFERENCES cities(id),
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SWISS BANK TRANSACTIONS
-- Full ledger of all credit transfers.
-- ============================================================
CREATE TABLE bank_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_account_id UUID REFERENCES accounts(id),
  to_account_id UUID REFERENCES accounts(id),
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'credits',
  -- credits | gold_coins
  reason TEXT,
  -- profession_income | mission_reward | player_transfer | purchase
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FOREIGN KEY ADDITIONS
-- Added after all tables exist.
-- ============================================================
ALTER TABLE professions
  ADD CONSTRAINT fk_profession_skill
  FOREIGN KEY (required_skill_id) REFERENCES skills(id);

ALTER TABLE skills
  ADD CONSTRAINT fk_skill_item
  FOREIGN KEY (required_item_id) REFERENCES item_templates(id);

-- ============================================================
-- INDEXES
-- Speed up the most common game queries.
-- ============================================================
CREATE INDEX idx_characters_account ON characters(account_id);
CREATE INDEX idx_characters_city ON characters(current_city_id);
CREATE INDEX idx_characters_alive ON characters(is_alive);
CREATE INDEX idx_tags_attacker ON tags(attacker_character_id);
CREATE INDEX idx_tags_target ON tags(target_character_id);
CREATE INDEX idx_tags_active ON tags(is_active, expires_at);
CREATE INDEX idx_inventory_character ON inventory(character_id);
CREATE INDEX idx_character_skills ON character_skills(character_id);
CREATE INDEX idx_ticker ON ticker_events(created_at DESC);
CREATE INDEX idx_dw_messages_to ON dw_messages(to_account_id, is_read);
CREATE INDEX idx_bank_transactions ON bank_transactions(from_account_id, to_account_id);

-- ============================================================
-- SEED: GAME CONFIG
-- Default tunable values.
-- ============================================================
INSERT INTO game_config (key, value, description) VALUES
  ('tag_duration_hours', '48', 'How long a tag lasts in real hours'),
  ('ap_regen_per_hour', '1', 'Action points recovered per real hour'),
  ('base_ap', '4', 'Starting action points before profession modifier'),
  ('intel_range_mod_same_country', '2.0', 'AP and credit multiplier for same country'),
  ('intel_range_mod_same_continent', '3.0', 'AP and credit multiplier for same continent'),
  ('intel_range_mod_cross_continent', '4.0', 'AP and credit multiplier for cross continent'),
  ('intel_sweep_mod', '5.0', 'Additional multiplier for city sweep'),
  ('air_ap_per_100px', '1', 'Air travel AP cost per 100 pixels'),
  ('air_credits_per_100px', '50', 'Air travel credit cost per 100 pixels'),
  ('rail_ap_per_100px', '2', 'Rail travel AP cost per 100 pixels'),
  ('rail_credits_per_100px', '30', 'Rail travel credit cost per 100 pixels'),
  ('water_ap_per_100px', '3', 'Water travel AP cost per 100 pixels'),
  ('water_credits_per_100px', '20', 'Water travel credit cost per 100 pixels'),
  ('road_ap_per_100px', '4', 'Road travel AP cost per 100 pixels'),
  ('road_credits_per_100px', '10', 'Road travel credit cost per 100 pixels'),
  ('death_credit_penalty', '500', 'Credits lost on death in standard server'),
  ('starting_credits', '500', 'Credits a new character starts with');

-- ============================================================
-- SEED: TRANSPORT MODES
-- ============================================================
INSERT INTO transport_modes (name, ap_per_100px, credits_per_100px) VALUES
  ('air', 1, 50),
  ('rail', 2, 30),
  ('water', 3, 20),
  ('road', 4, 10);

EOF
echo "Schema file created successfully"
