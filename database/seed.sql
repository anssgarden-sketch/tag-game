-- ============================================================
-- TAG: The Assassination Game
-- Seed Data v1
-- ============================================================

-- ============================================================
-- CITIES (20 major world cities with map pixel coordinates)
-- Coordinates based on a standard 1920x960 world map image
-- ============================================================
INSERT INTO cities (name, country, continent, map_x, map_y, has_airport, has_rail, has_port) VALUES
  ('New York',      'United States', 'North America', 380, 280, TRUE,  TRUE,  TRUE),
  ('Los Angeles',   'United States', 'North America', 220, 310, TRUE,  TRUE,  TRUE),
  ('Chicago',       'United States', 'North America', 350, 260, TRUE,  TRUE,  FALSE),
  ('Miami',         'United States', 'North America', 370, 340, TRUE,  FALSE, TRUE),
  ('London',        'United Kingdom','Europe',        760, 220, TRUE,  TRUE,  TRUE),
  ('Paris',         'France',        'Europe',        790, 240, TRUE,  TRUE,  FALSE),
  ('Berlin',        'Germany',       'Europe',        830, 210, TRUE,  TRUE,  FALSE),
  ('Moscow',        'Russia',        'Europe',        920, 190, TRUE,  TRUE,  FALSE),
  ('Istanbul',      'Turkey',        'Europe',        890, 270, TRUE,  TRUE,  TRUE),
  ('Dubai',         'UAE',           'Asia',          980, 340, TRUE,  FALSE, TRUE),
  ('Mumbai',        'India',         'Asia',          1040,380, TRUE,  TRUE,  TRUE),
  ('Bangkok',       'Thailand',      'Asia',          1120,370, TRUE,  TRUE,  FALSE),
  ('Singapore',     'Singapore',     'Asia',          1160,420, TRUE,  TRUE,  TRUE),
  ('Hong Kong',     'China',         'Asia',          1190,340, TRUE,  TRUE,  TRUE),
  ('Tokyo',         'Japan',         'Asia',          1270,280, TRUE,  TRUE,  TRUE),
  ('Sydney',        'Australia',     'Oceania',       1270,580, TRUE,  TRUE,  TRUE),
  ('Cairo',         'Egypt',         'Africa',        890, 330, TRUE,  TRUE,  FALSE),
  ('Lagos',         'Nigeria',       'Africa',        790, 400, TRUE,  FALSE, TRUE),
  ('Johannesburg',  'South Africa',  'Africa',        900, 520, TRUE,  TRUE,  FALSE),
  ('São Paulo',     'Brazil',        'South America', 480, 510, TRUE,  TRUE,  FALSE),
  ('Buenos Aires',  'Argentina',     'South America', 470, 580, TRUE,  TRUE,  TRUE),
  ('Mexico City',   'Mexico',        'North America', 270, 360, TRUE,  TRUE,  FALSE),
  ('Toronto',       'Canada',        'North America', 370, 250, TRUE,  TRUE,  FALSE),
  ('Madrid',        'Spain',         'Europe',        760, 270, TRUE,  TRUE,  FALSE),
  ('Rome',          'Italy',         'Europe',        830, 270, TRUE,  TRUE,  TRUE);

-- ============================================================
-- RAIL CONNECTIONS
-- Only geographically realistic land rail routes
-- ============================================================
WITH c AS (SELECT id, name FROM cities)
INSERT INTO rail_connections (city_a_id, city_b_id)
SELECT a.id, b.id FROM c a, c b WHERE
  (a.name = 'New York'    AND b.name = 'Chicago') OR
  (a.name = 'New York'    AND b.name = 'Toronto') OR
  (a.name = 'Chicago'     AND b.name = 'Los Angeles') OR
  (a.name = 'Chicago'     AND b.name = 'Toronto') OR
  (a.name = 'London'      AND b.name = 'Paris') OR
  (a.name = 'Paris'       AND b.name = 'Berlin') OR
  (a.name = 'Paris'       AND b.name = 'Madrid') OR
  (a.name = 'Paris'       AND b.name = 'Rome') OR
  (a.name = 'Berlin'      AND b.name = 'Moscow') OR
  (a.name = 'Berlin'      AND b.name = 'Rome') OR
  (a.name = 'Moscow'      AND b.name = 'Istanbul') OR
  (a.name = 'Istanbul'    AND b.name = 'Cairo') OR
  (a.name = 'Mumbai'      AND b.name = 'Bangkok') OR
  (a.name = 'Bangkok'     AND b.name = 'Singapore') OR
  (a.name = 'Bangkok'     AND b.name = 'Hong Kong') OR
  (a.name = 'Hong Kong'   AND b.name = 'Tokyo') OR
  (a.name = 'Mexico City' AND b.name = 'Los Angeles') OR
  (a.name = 'São Paulo'   AND b.name = 'Buenos Aires') OR
  (a.name = 'Johannesburg'AND b.name = 'Cairo');

-- ============================================================
-- WATER ROUTES
-- Port city connections only
-- ============================================================
WITH c AS (SELECT id, name FROM cities)
INSERT INTO water_routes (city_a_id, city_b_id)
SELECT a.id, b.id FROM c a, c b WHERE
  (a.name = 'New York'    AND b.name = 'London') OR
  (a.name = 'New York'    AND b.name = 'Miami') OR
  (a.name = 'New York'    AND b.name = 'São Paulo') OR
  (a.name = 'Miami'       AND b.name = 'Buenos Aires') OR
  (a.name = 'Miami'       AND b.name = 'Lagos') OR
  (a.name = 'London'      AND b.name = 'New York') OR
  (a.name = 'London'      AND b.name = 'Lagos') OR
  (a.name = 'London'      AND b.name = 'Singapore') OR
  (a.name = 'Istanbul'    AND b.name = 'Dubai') OR
  (a.name = 'Istanbul'    AND b.name = 'Cairo') OR
  (a.name = 'Dubai'       AND b.name = 'Mumbai') OR
  (a.name = 'Dubai'       AND b.name = 'Singapore') OR
  (a.name = 'Mumbai'      AND b.name = 'Singapore') OR
  (a.name = 'Singapore'   AND b.name = 'Hong Kong') OR
  (a.name = 'Singapore'   AND b.name = 'Sydney') OR
  (a.name = 'Hong Kong'   AND b.name = 'Tokyo') OR
  (a.name = 'Tokyo'       AND b.name = 'Los Angeles') OR
  (a.name = 'Sydney'      AND b.name = 'Los Angeles') OR
  (a.name = 'Lagos'       AND b.name = 'Johannesburg') OR
  (a.name = 'Buenos Aires'AND b.name = 'Rome') OR
  (a.name = 'Los Angeles' AND b.name = 'Sydney');

-- ============================================================
-- PROFESSIONS
-- ============================================================
INSERT INTO professions (name, description, credits_per_week, ap_modifier, schedule_type) VALUES
  ('Unemployed',          'No job, maximum freedom',                    0,    3,  'unemployed'),
  ('Freelancer',          'Contract work, flexible hours',              200,  2,  'freelance'),
  ('Street Informant',    'Eyes and ears on the ground',                100,  2,  'freelance'),
  ('Journalist',          'Covers stories, asks questions',             300,  1,  'part_time'),
  ('Private Investigator','Licensed to snoop',                          400,  1,  'part_time'),
  ('Security Consultant', 'Keeps others safe for a fee',                500,  0,  'part_time'),
  ('Arms Dealer',         'Sells weapons and gear discreetly',          600,  0,  'freelance'),
  ('Corporate Executive', 'High pay, no time for anything else',        2000, -3, 'full_time'),
  ('Government Agent',    'Works for the state, officially',            1500, -2, 'full_time'),
  ('Military Officer',    'Rank and discipline, little free time',      1200, -2, 'full_time'),
  ('Doctor',              'Heals people, long hospital shifts',         1800, -3, 'full_time'),
  ('Lawyer',              'Billable hours leave no time to breathe',    1600, -3, 'full_time'),
  ('University Professor','Tenure means stability, not freedom',        900,  -1, 'full_time'),
  ('Taxi Driver',         'Always on the move, knows every street',     250,  1,  'part_time'),
  ('Bartender',           'Hears everything, works nights',             200,  1,  'part_time');

-- ============================================================
-- SKILLS — INTEL / COUNTER-INTEL POOL
-- 30 skills shared between Intel and Counter-Intel
-- ============================================================
INSERT INTO skills (name, description, category, range, base_ap_cost, base_credit_cost) VALUES
  -- City range Intel skills
  ('Street Surveillance',   'Observe targets through street-level legwork',         'intel', 'city',      2, 50),
  ('Bar Network',           'Gather intel through informants in local bars',         'intel', 'city',      2, 80),
  ('Pickpocket Recon',      'Lift documents and IDs from targets in crowds',         'intel', 'city',      2, 30),
  ('Safe House Monitoring', 'Watch known safe house locations for activity',         'intel', 'city',      3, 100),
  ('Disguise Infiltration', 'Infiltrate target location using a disguise',           'intel', 'city',      3, 150),
  ('Dead Drop Check',       'Retrieve intelligence left at a dead drop location',    'intel', 'city',      1, 40),
  ('Courier Intercept',     'Intercept message couriers to read communications',     'intel', 'city',      2, 120),
  ('Local Bribery',         'Pay locals for information on target movements',        'intel', 'city',      1, 200),
  ('Photo Surveillance',    'Set up hidden cameras to monitor target location',      'intel', 'city',      3, 180),
  ('Newspaper Check',       'Scan local news and public records for intel',          'intel', 'city',      1, 10),
  -- Country range Intel skills
  ('Phone Tap',             'Tap target phone lines within the country',             'intel', 'country',   2, 300),
  ('Police Database Hack',  'Access national police records for target info',        'intel', 'country',   2, 400),
  ('Border Monitoring',     'Monitor border crossings for target movement',          'intel', 'country',   3, 250),
  ('Postal Intercept',      'Intercept mail and packages sent to target',            'intel', 'country',   2, 150),
  ('Bank Record Access',    'Access domestic banking records of target',             'intel', 'country',   3, 500),
  -- Continent range Intel skills
  ('Airline Manifest Hack', 'Access regional airline passenger manifests',           'intel', 'continent', 2, 600),
  ('Interpol Contact',      'Use Interpol connections to locate target regionally',  'intel', 'continent', 3, 800),
  ('Embassy Intelligence',  'Gather intel through embassy contacts',                 'intel', 'continent', 3, 700),
  ('Regional Satellite',    'Use regional satellite imagery to locate target',       'intel', 'continent', 2, 900),
  ('Dark Web Search',       'Search Dark Web forums for target information',         'intel', 'continent', 1, 500),
  -- Global range Intel skills
  ('Global Satellite Hack', 'Hack global satellite network to locate target',        'intel', 'global',    1, 2000),
  ('NSA Database Breach',   'Breach intelligence agency global databases',           'intel', 'global',    2, 3000),
  ('Facial Recognition Net','Use global CCTV facial recognition network',            'intel', 'global',    2, 2500),
  ('Deep Web Intelligence', 'Extract target data from deep web sources globally',   'intel', 'global',    1, 1800),
  ('Ghost Protocol Trace',  'Use classified ghost protocol to trace any target',     'intel', 'global',    1, 5000),
  -- Additional city skills
  ('Vehicle Tracking',      'Plant a tracker on target vehicle',                     'intel', 'city',      2, 220),
  ('Social Engineering',    'Manipulate contacts into revealing target location',    'intel', 'city',      2, 60),
  ('Garbage Intelligence',  'Search target garbage for useful documents',            'intel', 'city',      1, 0),
  ('Neighbor Inquiry',      'Question neighbors and building staff about target',    'intel', 'city',      1, 20),
  ('Hotel Registry Check',  'Check hotel registries for target check-in records',   'intel', 'city',      1, 80);

-- ============================================================
-- SKILLS — ASSASSINATION / DEFENSIVE POOL
-- 30 skills shared between Assassination and Defensive
-- ============================================================
INSERT INTO skills (name, description, category, range, base_ap_cost, base_credit_cost) VALUES
  -- Close range
  ('Garrote',           'Silent strangulation using a wire or cord',              'assassination', 'close',  1, 50),
  ('Poison',            'Administer poison through food, drink or contact',       'assassination', 'close',  1, 200),
  ('Knife',             'Fast and silent blade attack at close range',            'assassination', 'close',  1, 30),
  ('Death Touch',       'Precise pressure point strike causing cardiac arrest',   'assassination', 'close',  1, 0),
  ('Choke Hold',        'Render target unconscious then eliminate silently',      'assassination', 'close',  1, 0),
  ('Syringe',           'Inject lethal substance directly into target',           'assassination', 'close',  1, 150),
  -- Short range
  ('Shuriken',          'Thrown steel stars for short range silent kills',        'assassination', 'short',  1, 80),
  ('Blow Gun',          'Silent dart gun effective at short range',               'assassination', 'short',  1, 100),
  ('Throwing Knife',    'Accurately thrown blade at short range',                 'assassination', 'short',  1, 60),
  ('Sling',             'Ancient but effective short range projectile weapon',    'assassination', 'short',  1, 20),
  ('Spear',             'Thrown spear for short range elimination',               'assassination', 'short',  2, 40),
  ('Crossbow',          'Compact crossbow for quiet short range kills',           'assassination', 'short',  1, 120),
  -- Medium range
  ('Handgun',           'Standard sidearm for medium range engagements',         'assassination', 'medium', 1, 300),
  ('Shotgun',           'High stopping power at medium range',                   'assassination', 'medium', 2, 250),
  ('SMG',               'Submachine gun for rapid medium range fire',             'assassination', 'medium', 2, 400),
  ('Bow and Arrow',     'Silent bow for medium range precision kills',            'assassination', 'medium', 2, 150),
  ('Suppressed Pistol', 'Silenced handgun minimizing noise signature',           'assassination', 'medium', 1, 450),
  -- Long range
  ('Sniper Rifle',      'Long range precision rifle for distance kills',          'assassination', 'long',   2, 800),
  ('Assault Rifle',     'Versatile long range automatic weapon',                  'assassination', 'long',   2, 600),
  ('Anti-Material Rifle','Extreme long range rifle penetrating armor',            'assassination', 'long',   3, 1200),
  ('Designated Marksman','Precision semi-automatic rifle for long range',         'assassination', 'long',   2, 700),
  -- Remote range
  ('Car Bomb',          'Plant explosive device in target vehicle',               'assassination', 'remote', 3, 1500),
  ('IED',               'Improvised explosive device planted on route',           'assassination', 'remote', 3, 1000),
  ('Drone Strike',      'Deploy armed drone to eliminate target remotely',        'assassination', 'remote', 2, 5000),
  ('Poison Gas',        'Release targeted gas attack on target location',         'assassination', 'remote', 3, 3000),
  ('Cyber Kill',        'Hack target life support or vehicle systems remotely',   'assassination', 'remote', 2, 8000),
  -- Additional defensive-focused skills
  ('Bulletproof Vest',  'Body armor absorbing firearm impacts',                   'assassination', 'medium', 0, 500),
  ('Evasive Driving',   'Advanced driving to escape or avoid attackers',          'assassination', 'medium', 1, 200),
  ('Combat Training',   'Hand to hand combat proficiency for close defense',      'assassination', 'close',  1, 0),
  ('Counter Surveillance','Detect and evade surveillance operations',             'assassination', 'city',   1, 100);

