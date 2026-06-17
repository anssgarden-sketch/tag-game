#!/usr/bin/env bash
# TAG: Intel + Tag System Test
# Run: bash test_intel.sh
# All steps login fresh — no token expiry issues.

BASE="http://localhost:3001/api"
ATTACKER_EMAIL="shino01@gmail.com"
ATTACKER_PASS="password"
TARGET_EMAIL="target01@tag-game.com"
TARGET_PASS="password123"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC} $1"; }
fail() { echo -e "${RED}  FAIL${NC} $1"; }
info() { echo -e "${CYAN}  INFO${NC} $1"; }
header() { echo -e "\n${BOLD}${YELLOW}=== $1 ===${NC}"; }

# Login helper — prints token only
login() {
  local email=$1 pass=$2
  curl -s -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$pass\"}" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4
}

# Authenticated GET
aget() {
  local token=$1 path=$2
  curl -s -X GET "$BASE$path" -H "Authorization: Bearer $token"
}

# Authenticated POST
apost() {
  local token=$1 path=$2 body=$3
  curl -s -X POST "$BASE$path" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$body"
}

echo -e "${BOLD}TAG: Intel + Tag System Test${NC}"
echo "Base URL: $BASE"
echo "Attacker: $ATTACKER_EMAIL"
echo "Target:   $TARGET_EMAIL"

# ─────────────────────────────────────────────
header "1. Server health check"
# ─────────────────────────────────────────────
HEALTH=$(curl -s "http://localhost:3001/health")
echo "  $HEALTH"
if echo "$HEALTH" | grep -q '"status":"ok"'; then
  pass "Server is up"
else
  fail "Server not responding — start with: cd /workspaces/tag-game/backend && node src/server.js &"
  exit 1
fi

# ─────────────────────────────────────────────
header "2. Login both accounts"
# ─────────────────────────────────────────────
ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
if [ -z "$ATK_TOKEN" ]; then
  fail "Attacker login failed"
  exit 1
fi
pass "Attacker logged in (token: ${ATK_TOKEN:0:20}...)"

TGT_TOKEN=$(login "$TARGET_EMAIL" "$TARGET_PASS")
if [ -z "$TGT_TOKEN" ]; then
  fail "Target login failed"
  exit 1
fi
pass "Target logged in (token: ${TGT_TOKEN:0:20}...)"

# ─────────────────────────────────────────────
header "3. Fetch both characters"
# ─────────────────────────────────────────────
ATK_CHAR=$(aget "$ATK_TOKEN" "/character/me")
echo "  Attacker char: $ATK_CHAR" | head -c 300
echo

TGT_CHAR=$(aget "$TGT_TOKEN" "/character/me")
echo "  Target char:   $TGT_CHAR" | head -c 300
echo

# Extract attacker city id
ATK_CITY_ID=$(echo "$ATK_CHAR" | grep -o '"current_city_id":"[^"]*"' | cut -d'"' -f4)
if [ -z "$ATK_CITY_ID" ]; then
  fail "Could not read attacker current_city_id — check character exists"
else
  info "Attacker city ID: $ATK_CITY_ID"
fi

# Extract attacker intel skills
ATK_INTEL_SKILL=$(echo "$ATK_CHAR" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    char = d.get('character', {})
    skills = char.get('character_skills', [])
    intel = [s for s in skills if s.get('pool') == 'intel']
    if intel:
        sid = intel[0].get('skills', {}).get('id') or intel[0].get('skill_id', '')
        print(sid)
except:
    pass
" 2>/dev/null)

if [ -z "$ATK_INTEL_SKILL" ]; then
  fail "Could not extract attacker intel skill — checking raw character_skills structure..."
  echo "$ATK_CHAR" | python3 -c "
import sys, json
d = json.load(sys.stdin)
char = d.get('character', {})
skills = char.get('character_skills', [])
print('  Total skills:', len(skills))
for s in skills[:5]:
    print(' ', s)
" 2>/dev/null
else
  pass "Attacker intel skill ID: $ATK_INTEL_SKILL"
fi

# ─────────────────────────────────────────────
header "4. Check attacker's existing tags (should be empty)"
# ─────────────────────────────────────────────
# Fresh login for this step
ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
TAGS=$(aget "$ATK_TOKEN" "/intel/tags")
echo "  $TAGS"
if echo "$TAGS" | grep -q '"count":0'; then
  pass "No existing tags — clean state"
elif echo "$TAGS" | grep -q '"active_tags"'; then
  info "Existing tags found (will test refresh too)"
else
  fail "Unexpected tags response"
fi

# ─────────────────────────────────────────────
header "5. Intel search — single target by name, same city"
# ─────────────────────────────────────────────
if [ -z "$ATK_INTEL_SKILL" ] || [ -z "$ATK_CITY_ID" ]; then
  fail "Skipping — missing skill_id or city_id from step 3"
else
  ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
  SEARCH=$(apost "$ATK_TOKEN" "/intel/search" \
    "{\"target_name\":\"Phantom\",\"target_city_id\":\"$ATK_CITY_ID\",\"skill_id\":\"$ATK_INTEL_SKILL\",\"is_sweep\":false}")
  echo "  $SEARCH"

  if echo "$SEARCH" | grep -q '"tagged"'; then
    pass "Target tagged successfully"
  elif echo "$SEARCH" | grep -q '"result"'; then
    info "Search returned result (target not found or blocked): $(echo $SEARCH | grep -o '"result":"[^"]*"')"
  elif echo "$SEARCH" | grep -q '"error"'; then
    fail "Error: $(echo $SEARCH | grep -o '"error":"[^"]*"')"
  fi
fi

# ─────────────────────────────────────────────
header "6. Intel search — city sweep"
# ─────────────────────────────────────────────
if [ -z "$ATK_INTEL_SKILL" ] || [ -z "$ATK_CITY_ID" ]; then
  fail "Skipping — missing skill_id or city_id"
else
  ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
  SWEEP=$(apost "$ATK_TOKEN" "/intel/search" \
    "{\"target_city_id\":\"$ATK_CITY_ID\",\"skill_id\":\"$ATK_INTEL_SKILL\",\"is_sweep\":true}")
  echo "  $SWEEP"

  if echo "$SWEEP" | grep -q 'sweep complete'; then
    pass "Sweep completed"
  elif echo "$SWEEP" | grep -q '"error"'; then
    ERRMSG=$(echo "$SWEEP" | grep -o '"error":"[^"]*"')
    if echo "$ERRMSG" | grep -q "Insufficient AP"; then
      info "Out of AP after step 5 — expected. AP cost is working."
    else
      fail "Error: $ERRMSG"
    fi
  fi
fi

# ─────────────────────────────────────────────
header "7. Verify tags were created"
# ─────────────────────────────────────────────
ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
TAGS2=$(aget "$ATK_TOKEN" "/intel/tags")
echo "  $TAGS2"
TAG_COUNT=$(echo "$TAGS2" | grep -o '"count":[0-9]*' | cut -d: -f2)
if [ "$TAG_COUNT" -gt 0 ] 2>/dev/null; then
  pass "Tags in DB: $TAG_COUNT"
else
  info "No tags found — if single search also found nobody, that's expected with no overlap"
fi

# ─────────────────────────────────────────────
header "8. Error cases"
# ─────────────────────────────────────────────
ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")

# Missing skill_id
R=$(apost "$ATK_TOKEN" "/intel/search" \
  "{\"target_name\":\"Phantom\",\"target_city_id\":\"$ATK_CITY_ID\"}")
if echo "$R" | grep -q '"error"'; then
  pass "Missing skill_id rejected: $(echo $R | grep -o '"error":"[^"]*"')"
else
  fail "Missing skill_id should have been rejected"
fi

# Missing city_id
R=$(apost "$ATK_TOKEN" "/intel/search" \
  "{\"target_name\":\"Phantom\",\"skill_id\":\"$ATK_INTEL_SKILL\"}")
if echo "$R" | grep -q '"error"'; then
  pass "Missing city_id rejected: $(echo $R | grep -o '"error":"[^"]*"')"
else
  fail "Missing city_id should have been rejected"
fi

# Missing target_name on non-sweep
R=$(apost "$ATK_TOKEN" "/intel/search" \
  "{\"target_city_id\":\"$ATK_CITY_ID\",\"skill_id\":\"$ATK_INTEL_SKILL\",\"is_sweep\":false}")
if echo "$R" | grep -q '"error"'; then
  pass "Missing target_name on non-sweep rejected: $(echo $R | grep -o '"error":"[^"]*"')"
else
  fail "Should have required target_name when is_sweep=false"
fi

# Unauthenticated request
R=$(curl -s -X GET "$BASE/intel/tags")
if echo "$R" | grep -q '"error"'; then
  pass "Unauthenticated request blocked"
else
  fail "Unauthenticated request should have been blocked"
fi

# ─────────────────────────────────────────────
header "9. Check attacker AP was deducted correctly"
# ─────────────────────────────────────────────
ATK_TOKEN=$(login "$ATTACKER_EMAIL" "$ATTACKER_PASS")
ATK_CHAR2=$(aget "$ATK_TOKEN" "/character/me")
ATK_AP=$(echo "$ATK_CHAR2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ap = d.get('character', {}).get('action_points', {})
if isinstance(ap, list): ap = ap[0]
print(f'current={ap.get(\"current_ap\",\"?\")} max={ap.get(\"max_ap\",\"?\")}')
" 2>/dev/null)
info "Attacker AP after tests: $ATK_AP"

echo ""
echo -e "${BOLD}Test run complete.${NC}"
echo "─────────────────────────────────────────────────────"
echo "Next steps:"
echo "  • If step 5 shows 'No targets found' → both characters may not be in same city"
echo "    Fix: update Phantom's current_city_id in DB to match attacker's city"
echo "  • If step 5 shows 'You do not have this Intel skill' → skill pool seeding issue"
echo "    Fix: check character_skills rows for attacker with pool='intel'"
echo "  • If any step shows action_points NaN → make sure you deployed the fixed controller"
