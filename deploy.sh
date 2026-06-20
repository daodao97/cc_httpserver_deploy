#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${SCRIPT_DIR}/docker-compose.yml}"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"
UPSTREAM_FILE="${UPSTREAM_FILE:-${SCRIPT_DIR}/deploy/gateway-upstream.conf}"
DEFAULT_GATEWAY_SCALE="${GATEWAY_SCALE:-3}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_BASE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BASE=(docker-compose)
else
  echo "docker compose is required" >&2
  exit 1
fi

COMPOSE=("${COMPOSE_BASE[@]}" --project-directory "${SCRIPT_DIR}")
if [[ -f "${ENV_FILE}" ]]; then
  COMPOSE+=(--env-file "${ENV_FILE}")
fi
COMPOSE+=(-f "${COMPOSE_FILE}")

usage() {
  cat <<'USAGE'
Usage:
  ./deploy.sh <command> [args]

Commands:
  deploy [n]       Pull images and start the stack, scaling gateway to n replicas.
  up [n]           Alias for deploy.
  scale <n>        Scale gateway to n replicas and reload nginx upstreams.
  restart          Restart worker, refresh gateway upstreams, reload lb.
  restart-lb       Regenerate gateway upstreams and reload nginx.
  pull             Pull service images.
  logs [svc...]    Follow logs.
  ps               Show service status.
  health           Check service status and /healthz through nginx.
  config           Render docker compose config.
  stop             Stop containers.
  down             Remove containers and network, keeping ./data/mysql.

Environment:
  GATEWAY_SCALE=3
  HTTP_PORT=8080
  MYSQL_DATA_DIR=./data/mysql
  ENV_FILE=./.env
USAGE
}

compose() {
  "${COMPOSE[@]}" "$@"
}

gateway_ids() {
  compose ps -q gateway
}

gateway_scale_arg() {
  local value="${1:-${DEFAULT_GATEWAY_SCALE}}"
  if ! [[ "${value}" =~ ^[1-9][0-9]*$ ]]; then
    echo "gateway scale must be a positive integer" >&2
    exit 1
  fi
  printf '%s\n' "${value}"
}

container_ip() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1"
}

write_gateway_upstream() {
  local ids=("$@")
  local tmp="${UPSTREAM_FILE}.tmp"
  mkdir -p "$(dirname -- "${UPSTREAM_FILE}")"
  : > "${tmp}"

  local id ip
  for id in "${ids[@]}"; do
    ip="$(container_ip "${id}")"
    if [[ -n "${ip}" ]]; then
      printf 'server %s:3000;\n' "${ip}" >> "${tmp}"
    fi
  done

  if [[ ! -s "${tmp}" ]]; then
    printf 'server gateway:3000;\n' >> "${tmp}"
  fi

  cp "${tmp}" "${UPSTREAM_FILE}"
  rm -f "${tmp}"
}

reload_lb() {
  compose exec -T lb nginx -t
  compose exec -T lb nginx -s reload
}

refresh_gateway_upstream() {
  local ids
  mapfile -t ids < <(gateway_ids)
  write_gateway_upstream "${ids[@]}"
  if [[ -n "$(compose ps -q lb)" ]]; then
    reload_lb
  fi
}

wait_gateways_healthy() {
  local ids=("$@")
  local deadline=$((SECONDS + 180))
  local id status ready

  while (( SECONDS < deadline )); do
    ready=1
    for id in "${ids[@]}"; do
      status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${id}" 2>/dev/null || true)"
      if [[ "${status}" != "healthy" && "${status}" != "running" ]]; then
        ready=0
        break
      fi
    done
    [[ "${ready}" == "1" ]] && return 0
    sleep 2
  done

  echo "timed out waiting for gateway containers to become healthy" >&2
  exit 1
}

cmd_deploy() {
  local scale
  scale="$(gateway_scale_arg "${1:-}")"
  mkdir -p "${SCRIPT_DIR}/data/mysql" "${SCRIPT_DIR}/deploy"
  compose pull
  compose up -d --scale "gateway=${scale}" mysql redis worker gateway
  local ids
  mapfile -t ids < <(gateway_ids)
  wait_gateways_healthy "${ids[@]}"
  write_gateway_upstream "${ids[@]}"
  compose up -d --no-deps lb
  compose ps
}

cmd_scale() {
  local scale
  scale="$(gateway_scale_arg "${1:-}")"
  compose up -d --no-recreate --scale "gateway=${scale}" gateway
  local ids
  mapfile -t ids < <(gateway_ids)
  wait_gateways_healthy "${ids[@]}"
  refresh_gateway_upstream
  compose ps
}

cmd_restart() {
  compose restart worker
  refresh_gateway_upstream
  compose ps
}

cmd_health() {
  compose ps
  local port="${HTTP_PORT:-8080}"
  if [[ -f "${ENV_FILE}" ]]; then
    port="$(grep -E '^[[:space:]]*HTTP_PORT=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)"
    port="${port:-8080}"
  fi
  echo
  curl -fsS "http://127.0.0.1:${port}/healthz"
  echo
}

command="${1:-}"
if [[ -n "${command}" ]]; then
  shift
fi

case "${command}" in
  deploy|up)
    cmd_deploy "$@"
    ;;
  scale)
    cmd_scale "$@"
    ;;
  restart)
    cmd_restart
    ;;
  restart-lb)
    refresh_gateway_upstream
    ;;
  pull)
    compose pull
    ;;
  logs)
    compose logs -f "$@"
    ;;
  ps)
    compose ps
    ;;
  health)
    cmd_health
    ;;
  config)
    compose config
    ;;
  stop)
    compose stop
    ;;
  down)
    compose down
    ;;
  help|-h|--help|"")
    usage
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    usage >&2
    exit 1
    ;;
esac
