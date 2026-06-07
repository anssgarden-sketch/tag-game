
-- ============================================================
-- TAG: The Assassination Game — Seed Data
-- ============================================================

-- CITIES
INSERT INTO cities (name, region, population_cap, climate, description) VALUES
  ('New Meridian',   'Northeast', 500, 'temperate', 'A dense urban sprawl — financial district cover, crowded streets, high surveillance.'),
  ('Voss Harbor',    'Southeast', 400, 'humid',     'Port city. Dockworkers, smugglers, and old money coexist uneasily.'),
  ('Redstone Flats', 'Southwest', 350, 'arid',      'Desert city built on oil wealth. Wide boulevards, few witnesses.'),
  ('Coldwater',      'Northwest', 300, 'cold',      'Isolated mountain city. Long winters, tight-knit community, hard to hide.'),
  ('The Sprawl',     'Central',   600, 'variable',  'Megalopolis. Largest city. Every faction has a foothold here.');

-- PROFESSIONS
INSERT INTO professions (name, description, starting_bonus, icon_slug) VALUES
  ('Ghost',       'Specialist in stealth eliminations. Starts with bonus to evasion and disguise.',          '{"evasion": 10, "disguise": 8}',          'ghost'),
  ('Enforcer',    'Brute-force operative. Higher health pool, bonus to intimidation and open confrontation.','{"health": 15, "intimidation": 10}',       'enforcer'),
  ('Fixer',       'Underworld broker. Earns more from contracts, starts with a network contact.',           '{"contract_bonus": 12, "contacts": 1}',    'fixer'),
  ('Technician',  'Gadget and surveillance expert. Can hack, track, and disable targets remotely.',         '{"hacking": 10, "tracking": 8}',           'technician'),
  ('Grifter',     'Social manipulation specialist. Excels at extracting information and setting traps.',    '{"persuasion": 12, "deception": 10}',      'grifter');

-- SKILLS
INSERT INTO skills (name, description, profession_id, tier, cost_xp, effect_json) VALUES
  -- Ghost skills
  ('Shadow Step',     'Move through crowds undetected for 60 seconds.',               (SELECT id FROM professions WHERE name='Ghost'),      1, 100, '{"stealth_boost": 15, "duration_sec": 60}'),
  ('Dead Drop',       'Leave or retrieve information without being seen.',             (SELECT id FROM professions WHERE name='Ghost'),      2, 250, '{"intel_action": true}'),
  ('Clean Exit',      'Escape any zone instantly once per contract.',                  (SELECT id FROM professions WHERE name='Ghost'),      3, 500, '{"escape": true, "uses_per_contract": 1}'),

  -- Enforcer skills
  ('Iron Presence',   'Intimidate nearby players, reducing their action speed.',       (SELECT id FROM professions WHERE name='Enforcer'),   1, 100, '{"debuff": "action_speed", "reduction": 10}'),
  ('Hard Target',     'Reduce incoming damage by 20% for 30 seconds.',                (SELECT id FROM professions WHERE name='Enforcer'),   2, 250, '{"damage_reduction": 20, "duration_sec": 30}'),
  ('Blowback',        'Counter-contract: mark your attacker for a bonus bounty.',      (SELECT id FROM professions WHERE name='Enforcer'),   3, 500, '{"counter_contract": true, "bounty_bonus": 25}'),

  -- Fixer skills
  ('Street Intel',    'Reveal the current location of your target.',                  (SELECT id FROM professions WHERE name='Fixer'),      1, 100, '{"reveal_target": true}'),
  ('Black Market',    'Access discounted gear and forged documents.',                  (SELECT id FROM professions WHERE name='Fixer'),      2, 250, '{"shop_discount": 15}'),
  ('Double Contract', 'Take two active contracts simultaneously.',                     (SELECT id FROM professions WHERE name='Fixer'),      3, 500, '{"max_contracts": 2}'),

  -- Technician skills
  ('Tap Line',        'Intercept one message sent by a target player.',               (SELECT id FROM professions WHERE name='Technician'), 1, 100, '{"intercept": true}'),
  ('Ghost Signal',    'Make yourself appear in a false location for 2 minutes.',       (SELECT id FROM professions WHERE name='Technician'), 2, 250, '{"decoy_location": true, "duration_sec": 120}'),
  ('Killswitch',      'Disable a target's active skill for one contract phase.',       (SELECT id FROM professions WHERE name='Technician'), 3, 500, '{"disable_skill": true}'),

  -- Grifter skills
  ('Social Cover',    'Adopt a civilian persona; contracts against you are paused.',   (SELECT id FROM professions WHERE name='Grifter'),    1, 100, '{"contract_pause": true, "duration_sec": 90}'),
  ('Planted Info',    'Feed false intel to a player tracking you.',                   (SELECT id FROM professions WHERE name='Grifter'),    2, 250, '{"false_intel": true}'),
  ('Honey Trap',      'Lure a target to a location of your choosing.',                 (SELECT id FROM professions WHERE name='Grifter'),    3, 500, '{"lure_target": true}');

