#!/bin/bash
#
# Request an ACCESS_TOKEN to be used by a GitHub APP
# Environment variable that need to be set up:
# * APP_ID, the GitHub's app ID
# * APP_PRIVATE_KEY, the content of GitHub app's private key in PEM format.
# * APP_LOGIN, the login name used to install GitHub's app
#
# https://github.com/orgs/community/discussions/24743#discussioncomment-3245300
#

set -o pipefail
source /common.sh || { echo -e "ERROR: failed to import /common.sh"; exit 1; }

API_HEADER="Accept: application/vnd.github.${GH_API_VER}+json"
CONTENT_LENGTH_HEADER="Content-Length: 0"
APP_INSTALLATIONS_URI="${GH_API_ROOT}/app/installations"  # https://docs.github.com/en/rest/apps/apps#list-installations-for-the-authenticated-app


# JWT parameters based off
# https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps#authenticating-as-a-github-app
#
# JWT token issuance and expiration parameters
JWT_IAT_DRIFT=60
JWT_EXP_DELTA=600

JWT_JOSE_HEADER='{
    "alg": "RS256",
    "typ": "JWT"
}'


build_jwt_payload() {
    local now iat

    now=$(date +%s)
    iat=$((now - JWT_IAT_DRIFT))
    jq -ce \
        --arg iat_str "${iat}" \
        --arg exp_delta_str "${JWT_EXP_DELTA}" \
        --arg app_id_str "${APP_ID}" \
    '
        ($iat_str | tonumber) as $iat
        | ($exp_delta_str | tonumber) as $exp_delta
        | ($app_id_str | tonumber) as $app_id
        | .iat = $iat
        | .exp = ($iat + $exp_delta)
        | .iss = $app_id
    ' <<< '{}' | tr -d '\n'
}

base64url() {
    base64 | tr '+/' '-_' | tr -d '=\n'
}

rs256_sign() {
    openssl dgst -binary -sha256 -sign <(echo "$1")
}

# verify expected permissions have been granted to the App
verify_permissions() {
    local app perms k v
    app="$1"  # json blob

    declare -A perms
    perms=(
        [actions]=read
        [administration]=write
        [metadata]=read
    )
    [[ "$RUNNER_SCOPE" == org ]] && perms+=(
        [organization_administration]=read
        [organization_self_hosted_runners]=write
    )
    for k in "${!perms[@]}"; do
        v="$(jq -r ".permissions.$k" <<< "$app")"
        [[ "${perms[$k]}" == read && "$v" == write ]] && continue  # write granted where only read required, all good
        if [[ "$v" != "${perms[$k]}" ]]; then
            fail "app [$APP_ID] is missing [$k = ${perms[$k]}] permission, has [$k = $v]"
        fi
    done
}

request_access_token() {
    local jwt_payload encoded_jwt_parts encoded_mac generated_jwt auth_header
    local app_installations_response app access_token_url

    jwt_payload=$(build_jwt_payload) || fail "JWT payload construction failed w/ $?"
    encoded_jwt_parts=$(base64url <<<"${JWT_JOSE_HEADER}").$(base64url <<<"${jwt_payload}")
    encoded_mac=$(echo -n "${encoded_jwt_parts}" | rs256_sign "${APP_PRIVATE_KEY}" | base64url)
    generated_jwt="${encoded_jwt_parts}.${encoded_mac}"

    auth_header="Authorization: Bearer ${generated_jwt}"

    app_installations_response=$(curl -fs \
        -H "${auth_header}" \
        -H "${API_HEADER}" \
        "${APP_INSTALLATIONS_URI}" \
    ) || fail "fetching $APP_INSTALLATIONS_URI failed w/ $?"

    app=$(jq -re '.[] | select (.account.login == "'"${APP_LOGIN}"'" and .app_id == '"${APP_ID}"')' \
        <<< "$app_installations_response") || fail "couldn't find app with APP_LOGIN=$APP_LOGIN & APP_ID=$APP_ID in $APP_INSTALLATIONS_URI response"
    verify_permissions "$app"

    access_token_url=$(jq -re .access_tokens_url <<< "$app") || fail "no [.access_token_url] found in $APP_INSTALLATIONS_URI response"

    curl -fsX POST \
        -H "${CONTENT_LENGTH_HEADER}" \
        -H "${auth_header}" \
        -H "${API_HEADER}" \
        "${access_token_url}" | jq -re .token || fail "$access_token_url fetch & [.token] extraction failed with $?"
}

request_access_token
