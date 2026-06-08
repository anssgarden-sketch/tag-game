cat > /workspaces/tag-game/docs/DESIGN.md << 'EOF'
# TAG: The Assassination Game — Full Design Document

## Stack
- Frontend: React + Vite (port 5173)
- Backend: Node.js + Express (port 3001)
- Database: PostgreSQL on Supabase
- Repo: https://github.com/anssgarden-sketch/tag-game
- Environment: GitHub Codespaces

## Build Status
- [x] Database schema — 20 tables live on Supabase
- [x] Seed data — 25 cities, 15 professions, 60 skills
- [x] Authentication — register, login, /me protected route
- [ ] Character creation
- [ ] AP regeneration job
- [ ] Intel and tag system
- [ ] Assassination engine
- [ ] Travel system
- [ ] Dark Web
- [ ] Frontend UI

## Core Rules — Locked

### Currency
- Gold Coins: premium, scarce, purchasable with real money
- Credits ($): soft currency, earned weekly from profession
- Swiss bank format: SB-NNNN-XXXX

### Action Points
- Base: 4 AP
- Regen: 1 AP per real hour
- Modified by profession (+3 to -3)
- Can queue actions at 0 AP — costs committed immediately

### Skills
- 4 pools: 3 Assassination, 10 Defensive, 3 Intel, 10 Counter-Intel
- Chosen once at character creation from 60 skills per pair
- Each skill: name, description, ap_cost, credit_cost, item_requirement, range
- Exact skill match required to counter — no dice rolls

### Assassination Engine
- Phase 1 Intel: base_cost x range_mod x sweep_mod
- Range mods: same city x1, same country x2, same continent x3, cross-continent x4
- Sweep mod: x5 flat
- Phase 2 Tag: 48 hours or target arrives at destination, whichever first
- Phase 3 Execute: Close/Short/Medium/Long = same city hard cap, Remote = cross-city
- Counter-attack: automatic, Close-Long range only, same city, needs AP + credits
- Remote kills: no counter-attack, assassin anonymous

### Travel
- Pixel distance formula: sqrt((x2-x1)^2 + (y2-y1)^2)
- Air: 1AP/$50 per 100px, Rail: 2AP/$30, Water: 3AP/$20, Road: 4AP/$10
- In transit = still in departure city until landing
- Tag breaks on arrival at destination not on departure

### Death
- Permadeath server — no respawn
- is_alive = false gates all actions
- Death screen shows kill details
- Gold Coins and real-money items carry over to new character
- Credits, skills, inventory reset on new character

### Dark Web
- Maximum anonymity — no names ever revealed automatically
- Ticker tape: anonymized — "An unidentified body was found in [city]"
- NPC missions: guaranteed payout, multiple players can race
- Player contracts: trust-based, optional escrow for verified badge
- Dark Web handle separate from character name

## File Structure
/workspaces/tag-game/
  frontend/          React + Vite app
  backend/
    src/
      server.js
      routes/index.js
      routes/auth.js
      controllers/authController.js
      middleware/auth.js
      services/supabase.js
  database/
    schema.sql
    seed.sql
  docs/
    DESIGN.md