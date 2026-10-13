#!/bin/bash
# Walk the step-up flow through the deployed API:
# 1. requests without a token are rejected
# 2. a signed-in user reaches /info, which has no step-up rule
# 3. with a STEP_UP_REQUIRED rule on /transfer, the authorizer returns 401 and
#    records a step-up session in DynamoDB
# 4. the user answers a software token (TOTP) challenge, the session is marked
#    completed and /transfer succeeds
set -euo pipefail

USERNAME="ci-user-$(date +%s)"
PASSWORD="Ci-Passw0rd!"
SETTING_TABLE=step-up-auth-setting
SESSION_TABLE=step-up-auth-session

output() {
  lstk aws cloudformation describe-stacks \
    --query "Stacks[].Outputs[] | [?OutputKey=='$1'].OutputValue | [0]" --output text
}

USER_POOL_ID=$(output UserPoolId)
CLIENT_ID=$(output UserPoolClientId)
API=$(output StageUrl)
API=${API%/}
echo "User pool: $USER_POOL_ID, client: $CLIENT_ID, API: $API"
if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "None" ] || [ -z "$API" ] || [ "$API" = "None" ]; then
  echo "Test failed: stack outputs are missing, run make deploy first"
  exit 1
fi

# Print the status code, then the body, of a request to the API
call() {
  local method=$1 path=$2 response
  shift 2
  response=$(curl -s -m 60 -w '\n%{http_code}' -X "$method" "$API$path" "$@")
  echo "${response##*$'\n'}"
  echo "${response%$'\n'*}"
}

# expect <description> <status> <method> <path> [curl args...]
expect() {
  local description=$1 status=$2 result actual
  shift 2
  result=$(call "$@")
  actual=$(echo "$result" | head -1)
  if [ "$actual" != "$status" ]; then
    echo "Test failed: $description returned HTTP $actual, expected $status. Body: $(echo "$result" | tail -n +2)"
    exit 1
  fi
  echo "PASS: $description returned $status"
  BODY=$(echo "$result" | tail -n +2)
}

cleanup() {
  lstk aws dynamodb delete-item --table-name "$SETTING_TABLE" --key '{"id": {"S": "/transfer"}}' > /dev/null 2>&1 || true
  lstk aws cognito-idp admin-delete-user --user-pool-id "$USER_POOL_ID" --username "$USERNAME" > /dev/null 2>&1 || true
}
trap cleanup EXIT

lstk aws cognito-idp admin-create-user --user-pool-id "$USER_POOL_ID" --username "$USERNAME" \
  --user-attributes Name=email,Value="$USERNAME@example.com" Name=phone_number,Value=+15555550100 \
  --message-action SUPPRESS > /dev/null
lstk aws cognito-idp admin-set-user-password --user-pool-id "$USER_POOL_ID" --username "$USERNAME" \
  --password "$PASSWORD" --permanent
tokens=$(lstk aws cognito-idp initiate-auth --client-id "$CLIENT_ID" --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$USERNAME",PASSWORD="$PASSWORD" --query AuthenticationResult)
ACCESS_TOKEN=$(echo "$tokens" | jq -r .AccessToken)
ID_TOKEN=$(echo "$tokens" | jq -r .IdToken)
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Test failed: sign-in returned no access token: $tokens"
  exit 1
fi
echo "PASS: signed in as $USERNAME"

AUTH=(-H "Authorization: Bearer $ACCESS_TOKEN")
STEP_UP_AUTH=(-H "Authorization: Bearer $ACCESS_TOKEN" -H "Identification: $ID_TOKEN" -H 'Content-Type: application/json')

expect "GET /info without a token" 401 GET /info
expect "GET /info with a malformed token" 403 GET /info -H "Authorization: Bearer not-a-jwt"
expect "GET /info with the access token" 200 GET /info "${AUTH[@]}"
if ! echo "$BODY" | jq -e '.name == "info"' > /dev/null; then
  echo "Test failed: /info returned $BODY"
  exit 1
fi

lstk aws dynamodb put-item --table-name "$SETTING_TABLE" \
  --item '{"id": {"S": "/transfer"}, "stepUpState": {"S": "STEP_UP_REQUIRED"}}'
expect "POST /transfer before step-up" 401 POST /transfer "${AUTH[@]}"

# The authorizer keys the session by the access token's jti claim
JTI=$(echo "$ACCESS_TOKEN" | cut -d. -f2 | python3 -c '
import base64, json, sys
payload = sys.stdin.read().strip()
print(json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["jti"])')
session_status() {
  lstk aws dynamodb get-item --table-name "$SESSION_TABLE" --key "{\"sessionId\": {\"S\": \"$JTI\"}}" \
    --query Item.stepUpStatus.S --output text
}
status=$(session_status)
if [ "$status" != "STEP_UP_REQUIRED" ]; then
  echo "Test failed: session $JTI has status '$status', expected STEP_UP_REQUIRED"
  exit 1
fi
echo "PASS: the authorizer recorded a STEP_UP_REQUIRED session"

expect "POST /initiate-auth" 200 POST /initiate-auth "${STEP_UP_AUTH[@]}"
step_up_type=$(echo "$BODY" | jq -r .code)
if [ "$step_up_type" != "MAYBE_SOFTWARE_TOKEN_STEP_UP" ]; then
  echo "Test failed: /initiate-auth returned $BODY, expected MAYBE_SOFTWARE_TOKEN_STEP_UP for a user without MFA"
  exit 1
fi

SECRET=$(lstk aws cognito-idp associate-software-token --access-token "$ACCESS_TOKEN" --query SecretCode --output text)
CODE=$(python3 -c '
import base64, hashlib, hmac, struct, sys, time
secret = sys.argv[1]
key = base64.b32decode(secret + "=" * (-len(secret) % 8), casefold=True)
digest = hmac.new(key, struct.pack(">Q", int(time.time()) // 30), hashlib.sha1).digest()
offset = digest[-1] & 0x0F
print("%06d" % ((struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF) % 1000000))' "$SECRET")

expect "POST /respond-to-challenge with a wrong code" 401 POST /respond-to-challenge "${STEP_UP_AUTH[@]}" \
  -d "{\"step-up-type\": \"$step_up_type\", \"challenge-response\": \"12345\"}"
expect "POST /respond-to-challenge with the TOTP code" 200 POST /respond-to-challenge "${STEP_UP_AUTH[@]}" \
  -d "{\"step-up-type\": \"$step_up_type\", \"challenge-response\": \"$CODE\"}"

status=$(session_status)
if [ "$status" != "STEP_UP_COMPLETED" ]; then
  echo "Test failed: session $JTI has status '$status' after the challenge, expected STEP_UP_COMPLETED"
  exit 1
fi
echo "PASS: the challenge marked the session STEP_UP_COMPLETED"

expect "POST /transfer after step-up" 200 POST /transfer "${AUTH[@]}"
if [ "$BODY" != "dummy /transfer successful" ]; then
  echo "Test failed: /transfer returned '$BODY'"
  exit 1
fi

echo "Test passed: step-up authentication protected /transfer until the challenge succeeded"
