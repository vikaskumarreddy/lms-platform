#!/usr/bin/env bash
# End-to-end check of the subscription system against a running instance.
#
# Exercises the behaviours that are easy to get wrong and hard to notice:
#   1. creating an organization actually starts a subscription term with a frozen snapshot
#   2. faculty seats hard-block at the plan limit, with an actionable error
#   3. the same faculty email is still usable in a different tenant (the per-org
#      uniqueness fix)
#   4. student activity is metered idempotently — repeat logins do not double-bill
#   5. the Account page reports the right plan, usage and "Current Plan" button state
#   6. editing a plan's price does NOT reprice an existing tenant (grandfathering)
#   7. an expired subscription drops to read-only rather than a blank portal
#
# Usage: BASE=http://localhost:8099 ./e2e-subscription-check.sh
set -uo pipefail

BASE="${BASE:-http://localhost:8099}"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

jqp() { python -c "import sys,json;d=json.load(sys.stdin);print($1)" 2>/dev/null; }

TOKEN=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
  -d '{"email":"admin@axisora.com","password":"admin123"}' | jqp "d['accessToken']")
if [ -z "$TOKEN" ]; then
  echo "Could not log in as the platform admin — is the app running on $BASE?"
  exit 1
fi
AUTH="Authorization: Bearer $TOKEN"
JSON='Content-Type: application/json'

echo
echo "== 1. Organization creation starts a real subscription =="
PLATFORM_ID=$(curl -s "$BASE/api/org-subscriptions" -H "$AUTH" \
  | jqp "[p['id'] for p in d if p['code']=='PLATFORM'][0]")
SLUG="acme$RANDOM"
ORG=$(curl -s -X POST "$BASE/api/organizations" -H "$AUTH" -H "$JSON" -d "{
  \"name\":\"Acme Academy\",\"slug\":\"$SLUG\",\"orgSubscriptionId\":$PLATFORM_ID,
  \"billingCycle\":\"MONTHLY\",\"legalName\":\"Acme Academy Pvt Ltd\",
  \"gstin\":\"36AABCA1234A1Z5\",\"placeOfSupply\":\"Telangana\",\"stateCode\":\"36\",
  \"salesOwner\":\"Vamsi\",\"poNumber\":\"PO-2026-001\"}")
ORG_ID=$(echo "$ORG" | jqp "d['id']")

if [ -n "$ORG_ID" ]; then
  pass "organization created (id=$ORG_ID)"
else
  fail "organization creation" "$ORG"
  exit 1
fi

SUB=$(curl -s "$BASE/api/platform/subscriptions/$ORG_ID" -H "$AUTH")
PLAN_CODE=$(echo "$SUB" | jqp "d['planCode']")
LIMIT=$(echo "$SUB" | jqp "d['limits']['MAX_ACTIVE_STUDENTS']")
PRICE=$(echo "$SUB" | jqp "d['instance']['unitPrice']")
[ "$PLAN_CODE" = "PLATFORM" ] && pass "subscription instance on PLATFORM" \
  || fail "subscription instance" "planCode=$PLAN_CODE"
[ "$LIMIT" = "200" ] && pass "limits snapshot frozen at 200 students" \
  || fail "limits snapshot" "got $LIMIT"
[ "${PRICE%.*}" = "4999" ] && pass "price frozen at 4999.00" || fail "frozen price" "got $PRICE"

GSTIN=$(echo "$ORG" | jqp "d['gstin']")
[ "$GSTIN" = "36AABCA1234A1Z5" ] && pass "GST identity saved at creation" \
  || fail "GST identity" "got $GSTIN"

echo
echo "== 2. Faculty seats hard-block at the plan limit (5 on Platform) =="
ADMIN_EMAIL="head$RANDOM@acme.test"
curl -s -X POST "$BASE/api/organizations/$ORG_ID/admin" -H "$AUTH" -H "$JSON" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"name\":\"Head\",\"password\":\"acme12345\"}" >/dev/null

TENANT_TOKEN=$(curl -s -X POST "$BASE/api/auth/login" -H "$JSON" -H "X-Tenant-Slug: $SLUG" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"acme12345\"}" | jqp "d['accessToken']")
if [ -z "$TENANT_TOKEN" ]; then
  fail "tenant admin login" "no token"
else
  pass "tenant admin can log in"
  TAUTH="Authorization: Bearer $TENANT_TOKEN"

  # One seat is already used by the admin just created, so seats 2..5 should succeed
  # and the 6th should be refused.
  BLOCKED=""
  for i in 2 3 4 5 6; do
    RESP=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/faculty" -H "$TAUTH" -H "$JSON" \
      -H "X-Tenant-Slug: $SLUG" \
      -d "{\"name\":\"Faculty $i\",\"email\":\"fac$i.$RANDOM@acme.test\",\"password\":\"pass12345\"}")
    CODE=$(echo "$RESP" | tail -1)
    BODY=$(echo "$RESP" | sed '$d')
    if [ "$CODE" != "200" ]; then
      BLOCKED="$BODY"
      echo "        blocked at seat $i (HTTP $CODE)"
      break
    fi
  done

  if [ -n "$BLOCKED" ]; then
    ERR_CODE=$(echo "$BLOCKED" | jqp "d['code']")
    UPGRADE=$(echo "$BLOCKED" | jqp "d['details'].get('upgradeToPlanName','')")
    MSG=$(echo "$BLOCKED" | jqp "d['message']")
    [ "$ERR_CODE" = "QUOTA_FACULTY_ACCOUNTS_EXCEEDED" ] \
      && pass "typed quota code returned" || fail "quota code" "got $ERR_CODE"
    [ -n "$UPGRADE" ] && pass "error names an upgrade path: $UPGRADE" \
      || fail "upgrade path" "details carried no upgradeToPlanName"
    echo "        message: $MSG"
  else
    fail "faculty seat limit" "6 faculty were created without hitting the 5-seat limit"
  fi
fi

echo
echo "== 3. Same faculty email works in a different tenant =="
SLUG2="beta$RANDOM"
ORG2_ID=$(curl -s -X POST "$BASE/api/organizations" -H "$AUTH" -H "$JSON" -d "{
  \"name\":\"Beta Institute\",\"slug\":\"$SLUG2\",\"orgSubscriptionId\":$PLATFORM_ID,
  \"placeOfSupply\":\"Karnataka\",\"stateCode\":\"29\"}" | jqp "d['id']")
SHARED="shared$RANDOM@example.com"
A2_EMAIL="head2$RANDOM@beta.test"
curl -s -X POST "$BASE/api/organizations/$ORG_ID/admin" -H "$AUTH" -H "$JSON" \
  -d "{\"email\":\"$SHARED\",\"name\":\"Shared A\",\"password\":\"acme12345\"}" >/dev/null
R2=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/organizations/$ORG2_ID/admin" -H "$AUTH" -H "$JSON" \
  -d "{\"email\":\"$SHARED\",\"name\":\"Shared B\",\"password\":\"acme12345\"}")
[ "$(echo "$R2" | tail -1)" = "200" ] \
  && pass "same email accepted in a second organization" \
  || fail "per-org email uniqueness" "$(echo "$R2" | sed '$d')"

echo
echo "== 4. Student activity is metered idempotently =="
STU_EMAIL="stu$RANDOM@acme.test"
if [ -n "${TENANT_TOKEN:-}" ]; then
  curl -s -X POST "$BASE/api/students" -H "Authorization: Bearer $TENANT_TOKEN" -H "$JSON" \
    -H "X-Tenant-Slug: $SLUG" \
    -d "{\"name\":\"Test Student\",\"email\":\"$STU_EMAIL\",\"password\":\"stud12345\"}" >/dev/null
  for _ in 1 2 3; do
    curl -s -X POST "$BASE/api/auth/login" -H "$JSON" -H "X-Tenant-Slug: $SLUG" \
      -d "{\"email\":\"$STU_EMAIL\",\"password\":\"stud12345\"}" >/dev/null
  done
  ACTIVE=$(curl -s "$BASE/api/platform/subscriptions/$ORG_ID" -H "$AUTH" \
    | jqp "d['usage']['MAX_ACTIVE_STUDENTS']")
  [ "$ACTIVE" = "1" ] && pass "3 logins produced exactly 1 active student" \
    || fail "activity metering" "active students = $ACTIVE (expected 1)"
fi

echo
echo "== 5. Account page reports plan, usage and button state =="
if [ -n "${TENANT_TOKEN:-}" ]; then
  CARDS=$(curl -s "$BASE/api/account/plans" -H "Authorization: Bearer $TENANT_TOKEN" \
    -H "X-Tenant-Slug: $SLUG")
  CURRENT=$(echo "$CARDS" | jqp "[c['plan']['code'] for c in d if c['isCurrent']][0]")
  CURRENT_LABEL=$(echo "$CARDS" | jqp "[c['actionLabel'] for c in d if c['isCurrent']][0]")
  UPGRADES=$(echo "$CARDS" | jqp "len([c for c in d if c['action']=='UPGRADE'])")
  [ "$CURRENT" = "PLATFORM" ] && pass "current plan flagged as PLATFORM" \
    || fail "current plan flag" "got $CURRENT"
  [ "$CURRENT_LABEL" = "Current Plan" ] && pass "applied plan button reads 'Current Plan'" \
    || fail "current plan label" "got '$CURRENT_LABEL'"
  [ "$UPGRADES" -ge 1 ] && pass "$UPGRADES other plan(s) offer an action" \
    || fail "upgrade options" "no upgradeable plans offered"
fi

echo
echo "== 6. Editing a plan price does not reprice an existing tenant =="
curl -s -X PUT "$BASE/api/org-subscriptions/$PLATFORM_ID" -H "$AUTH" -H "$JSON" \
  -d '{"priceMonthly":6999,"priceYearly":69999}' >/dev/null
AFTER=$(curl -s "$BASE/api/platform/subscriptions/$ORG_ID" -H "$AUTH" | jqp "d['instance']['unitPrice']")
[ "${AFTER%.*}" = "4999" ] \
  && pass "existing tenant still on the agreed 4999.00 after a catalog price rise" \
  || fail "grandfathering" "tenant price became $AFTER"
curl -s -X PUT "$BASE/api/org-subscriptions/$PLATFORM_ID" -H "$AUTH" -H "$JSON" \
  -d '{"priceMonthly":4999,"priceYearly":49999}' >/dev/null

echo
echo "== 7. Expiry produces read-only with a message, not a blank portal =="
docker exec lms_postgres psql -U lms -d lms_e2e -q -c \
  "UPDATE org_subscription_instances SET period_end = NOW() - interval '60 days',
     grace_ends_at = NOW() - interval '45 days' WHERE organization_id = $ORG_ID;" >/dev/null 2>&1
if [ -n "${TENANT_TOKEN:-}" ]; then
  OVERVIEW=$(curl -s "$BASE/api/account/overview" -H "Authorization: Bearer $TENANT_TOKEN" \
    -H "X-Tenant-Slug: $SLUG")
  NOTICE=$(echo "$OVERVIEW" | jqp "d['notice']['code']")
  [ "$NOTICE" = "SUBSCRIPTION_EXPIRED" ] \
    && pass "Account page still loads and explains the expiry" \
    || fail "expiry notice" "notice code = $NOTICE"

  WRITE=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/faculty" \
    -H "Authorization: Bearer $TENANT_TOKEN" -H "$JSON" -H "X-Tenant-Slug: $SLUG" \
    -d "{\"name\":\"Blocked\",\"email\":\"blocked$RANDOM@acme.test\",\"password\":\"pass12345\"}")
  WCODE=$(echo "$WRITE" | tail -1)
  WBODY=$(echo "$WRITE" | sed '$d')
  [ "$WCODE" = "402" ] && pass "writes refused with 402 Payment Required" \
    || fail "read-only enforcement" "HTTP $WCODE: $WBODY"

  READ=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/students" \
    -H "Authorization: Bearer $TENANT_TOKEN" -H "X-Tenant-Slug: $SLUG")
  [ "$READ" = "200" ] && pass "reads still permitted (data is not lost)" \
    || fail "read access after expiry" "HTTP $READ"
fi

echo
echo "==============================="
echo "  $PASS passed, $FAIL failed"
echo "==============================="
[ "$FAIL" -eq 0 ]
