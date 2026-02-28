#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
TEMPLATE_FILE="/app/config.template.json"
OUTPUT_FILE="/tmp/config.json"

if [[ ! -f "${OPTIONS_FILE}" ]]; then
  echo "Missing ${OPTIONS_FILE}. This container expects Home Assistant add-on runtime."
  exit 1
fi

get_opt() {
  local key="$1"
  jq -r ".${key}" "${OPTIONS_FILE}"
}

required_opt() {
  local key="$1"
  local val
  val="$(get_opt "${key}")"
  if [[ -z "${val}" || "${val}" == "null" ]]; then
    echo "Missing required option: ${key}"
    exit 1
  fi
  printf '%s' "${val}"
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

COOKIE_SECRET_PATH="$(required_opt cookie_secret_path)"
COOKIE_SECRET_LENGTH="$(required_opt cookie_secret_length)"

if [[ ! -s "${COOKIE_SECRET_PATH}" ]]; then
  mkdir -p "$(dirname "${COOKIE_SECRET_PATH}")"
  set +o pipefail
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${COOKIE_SECRET_LENGTH}" >"${COOKIE_SECRET_PATH}"
  set -o pipefail
  chmod 600 "${COOKIE_SECRET_PATH}"
fi

ACTUAL_SECRET_LEN="$(wc -c < "${COOKIE_SECRET_PATH}" | tr -d ' ')"
if [[ "${ACTUAL_SECRET_LEN}" -ne "${COOKIE_SECRET_LENGTH}" ]]; then
  echo "Cookie secret length mismatch: expected ${COOKIE_SECRET_LENGTH}, got ${ACTUAL_SECRET_LEN}"
  exit 1
fi

PUBLIC_URI="$(required_opt public_uri)"
SESSION_SERVER_NAME="$(required_opt session_server_name)"
SESSION_AGE="$(required_opt session_age)"
ALLOWED_GROUPS_REGEX="$(required_opt allowed_groups_regex)"
ENTRA_CLIENT_ID="$(required_opt entra_client_id)"
ENTRA_CLIENT_SECRET="$(required_opt entra_client_secret)"
ENTRA_CONFIGURATION_URI="$(required_opt entra_configuration_uri)"
ENTRA_SCOPE="$(required_opt entra_scope)"
UPSTREAM_HOST="$(required_opt upstream_host)"
UPSTREAM_PORT="$(required_opt upstream_port)"
UPSTREAM_SSL="$(required_opt upstream_ssl)"
UPSTREAM_PATH="$(required_opt upstream_path)"
LISTEN_PORT="$(required_opt listen_port)"
SSL_ENABLED="$(required_opt ssl)"
CERTFILE="$(required_opt certfile)"
KEYFILE="$(required_opt keyfile)"

TLS_CERT_PATH=""
TLS_KEY_PATH=""
if [[ "${SSL_ENABLED,,}" == "true" ]]; then
  TLS_CERT_PATH="/ssl/${CERTFILE}"
  TLS_KEY_PATH="/ssl/${KEYFILE}"
  if [[ ! -f "${TLS_CERT_PATH}" ]]; then
    echo "Configured certfile not found: ${TLS_CERT_PATH}"
    exit 1
  fi
  if [[ ! -f "${TLS_KEY_PATH}" ]]; then
    echo "Configured keyfile not found: ${TLS_KEY_PATH}"
    exit 1
  fi
fi

sed \
  -e "s/__PUBLIC_URI__/$(escape_sed "${PUBLIC_URI}")/g" \
  -e "s/__SESSION_SERVER_NAME__/$(escape_sed "${SESSION_SERVER_NAME}")/g" \
  -e "s/__SESSION_AGE__/$(escape_sed "${SESSION_AGE}")/g" \
  -e "s/__ALLOWED_GROUPS_REGEX__/$(escape_sed "${ALLOWED_GROUPS_REGEX}")/g" \
  -e "s/__ENTRA_CLIENT_ID__/$(escape_sed "${ENTRA_CLIENT_ID}")/g" \
  -e "s/__ENTRA_CLIENT_SECRET__/$(escape_sed "${ENTRA_CLIENT_SECRET}")/g" \
  -e "s#__ENTRA_CONFIGURATION_URI__#$(escape_sed "${ENTRA_CONFIGURATION_URI}")#g" \
  -e "s/__ENTRA_SCOPE__/$(escape_sed "${ENTRA_SCOPE}")/g" \
  -e "s/__UPSTREAM_HOST__/$(escape_sed "${UPSTREAM_HOST}")/g" \
  -e "s/__UPSTREAM_PORT__/$(escape_sed "${UPSTREAM_PORT}")/g" \
  -e "s/__UPSTREAM_SSL__/$(escape_sed "${UPSTREAM_SSL}")/g" \
  -e "s#__UPSTREAM_PATH__#$(escape_sed "${UPSTREAM_PATH}")#g" \
  -e "s#__COOKIE_SECRET_PATH__#$(escape_sed "${COOKIE_SECRET_PATH}")#g" \
  -e "s#__TLS_CERT_PATH__#$(escape_sed "${TLS_CERT_PATH}")#g" \
  -e "s#__TLS_KEY_PATH__#$(escape_sed "${TLS_KEY_PATH}")#g" \
  "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"

jq --arg ssl_enabled "${SSL_ENABLED}" '
  .session.sessionAge |= tonumber
  | .services[0].port |= tonumber
  | .services[0].ssl |= (ascii_downcase == "true")
  | if ($ssl_enabled | ascii_downcase) == "true" then . else del(.tls) end
' "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp"
mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"

jq empty "${OUTPUT_FILE}" >/dev/null

exec java \
  -Xss512k \
  -Xmx256m \
  -XX:+UseG1GC \
  -Ddisable.socket.inherit=true \
  -Dvertx.cacheDirBase=/tmp \
  -Dport="${LISTEN_PORT}" \
  -jar /app/backend.jar \
  -conf "${OUTPUT_FILE}"
