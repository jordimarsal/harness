#!/usr/bin/env bash
#
# sonar-review.sh — SonarQube quality gate for the review step.
#
# Installed by the harness `sonarqube` module. Runs before the reviewer's
# verdict: scans the project (sonar-scanner binary, or the scanner Docker
# image), waits for the Compute Engine and the Quality Gate, and reports.
# When no server is reachable or no scanner exists it exits 2 — a recorded
# skip, never a fake pass.
#
# Usage:
#   bash harness/tools/sonar-review.sh [options]
#
# Options:
#   -k KEY        project key (default: sonar-project.properties, then the
#                 git remote as owner:repo, then the directory name)
#   --mode=M      scan | api | auto | off   (default: auto — scan when a
#                 scanner exists, api (last analysis) when only the server
#                 is reachable, off skips loudly)
#   --report-only never exit 1 on a failed gate: report FAILED, exit 0
#   --timeout S   seconds to wait for the Compute Engine and the gate (600)
#   --json        machine-readable report on stdout (progress goes to stderr)
#   -h            this help
#
# Exit codes:
#   0  quality gate PASSED (or FAILED reported under --report-only)
#   1  quality gate FAILED — the reviewer rejects the approval
#   2  SonarQube not available (no token, server down, no scanner) — skip,
#      record the reason; this is not evidence of quality either way
#   3  analysis error (scan failed, Compute Engine failed, gate unreadable)
#      while the server was reachable — skip, record; do not treat as a pass
#
# Configuration (checked in order):
#   1. environment: SONAR_HOST_URL + SONAR_TOKEN
#   2. harness/sonar.env (KEY=VALUE lines, gitignored — never commit tokens)
#   3. no token found → exit 2
# Extras honoured when present: SONAR_ORG (SonarQube Cloud organization),
# SONAR_SCANNER_BIN (binary path), SONAR_SCANNER_IMAGE (Docker image, default
# sonarsource/sonar-scanner-cli), SONAR_CONTAINER (server container name for
# auto-discovery, default sonarqube), SONAR_SCANNER_NETWORK (docker network to
# run the scanner container on).
set -u

TIMEOUT=600
MODE="auto"
REPORT_ONLY=0
JSON_OUT=0
PROJECT_KEY=""
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"      # harness/tools
PROJECT_DIR="$(cd "$SELF_DIR/../.." && pwd)"   # repo root

usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -k) PROJECT_KEY="${2:?sonar-review: -k needs a value}"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --report-only) REPORT_ONLY=1; shift ;;
    --timeout=*) TIMEOUT="${1#--timeout=}"; shift ;;
    --timeout) TIMEOUT="${2:?sonar-review: --timeout needs seconds}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'sonar-review: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

VERDICT="SKIPPED"
REASON=""
MODE_USED="none"
GATE_STATUS=""
FAILED_CONDITIONS=""

# ── Output helpers ──────────────────────────────────────────────────────────
# --json keeps stdout pure: progress goes to stderr in every mode.
emit() {  # emit <exit-code> — write the final report and exit
  local code="$1"
  if [ "$JSON_OUT" -eq 1 ]; then
    printf '{"verdict":"%s","mode":"%s","projectKey":"%s","qualityGate":"%s","failedConditions":[%s],"reason":"%s"}\n' \
      "$VERDICT" "$MODE_USED" "$PROJECT_KEY" "$GATE_STATUS" "$FAILED_CONDITIONS" "$REASON"
  else
    printf 'sonar-review: verdict=%s mode=%s project=%s gate=%s\n' \
      "$VERDICT" "$MODE_USED" "$PROJECT_KEY" "${GATE_STATUS:-none}"
    [ -n "$REASON" ] && printf 'sonar-review: %s\n' "$REASON"
    [ -n "$FAILED_CONDITIONS" ] && printf 'sonar-review: failed conditions: %s\n' "$FAILED_CONDITIONS"
  fi
  if [ "$code" -eq 1 ] && [ "$REPORT_ONLY" -eq 1 ]; then
    printf 'sonar-review: --report-only — FAILED reported, not enforced\n' >&2
    exit 0
  fi
  exit "$code"
}

info() { printf 'sonar-review: %s\n' "$*" >&2; }

DISCOVERED_NETWORK=""

api() {  # api <path> <query> — authenticated GET, body on stdout, "" on failure
  # No -f: HTTP-level errors (404 unknown project…) carry a JSON body we read.
  curl -sS --max-time 30 -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL%/}$1?$2" 2>/dev/null || true
}

json_get() {  # json_get <json> <what> — what ∈ server-status | ce-status | gate-status | gate-failed | api-error
  printf '%s' "$1" | python3 -c '
import sys, json
what = sys.argv[1]
try:
    obj = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
try:
    if what == "server-status":
        print(obj.get("status") or "")
    elif what == "ce-status":
        print((obj.get("task") or {}).get("status") or "")
    elif what == "gate-status":
        print((obj.get("projectStatus") or {}).get("status") or "")
    elif what == "gate-failed":
        ps = obj.get("projectStatus") or {}
        print(",".join("\"%s\"" % str(c.get("metricKey", "?")) for c in ps.get("conditions", []) if c.get("status") == "ERROR"))
    elif what == "api-error":
        errs = obj.get("errors") or []
        print("; ".join(str(e.get("msg", "")) for e in errs if e.get("msg")))
    else:
        print("")
except Exception:
    print("")' "$2" 2>/dev/null || true
}

# ── Configuration ───────────────────────────────────────────────────────────
if [ -z "${SONAR_HOST_URL:-}" ] || [ -z "${SONAR_TOKEN:-}" ]; then
  if [ -f "$PROJECT_DIR/harness/sonar.env" ]; then
    # shellcheck disable=SC1091  # project-local by design; gitignored
    . "$PROJECT_DIR/harness/sonar.env"
    info "config from harness/sonar.env"
  fi
fi
[ -n "${SONAR_HOST_URL:-}" ] || SONAR_HOST_URL="http://localhost:9000"
if [ -z "${SONAR_TOKEN:-}" ]; then
  VERDICT="SKIPPED"; REASON="no SONAR_TOKEN in environment or harness/sonar.env"
  emit 2
fi

# ── Project key ─────────────────────────────────────────────────────────────
if [ -z "$PROJECT_KEY" ]; then
  PROJECT_KEY="$(sed -n 's/^[[:space:]]*sonar\.projectKey[[:space:]]*=[[:space:]]*//p' \
    "$PROJECT_DIR/sonar-project.properties" 2>/dev/null | head -1 | tr -d '[:space:]')"
fi
if [ -z "$PROJECT_KEY" ] && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REMOTE="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)"
  if [ -n "$REMOTE" ]; then
    # git@host:owner/repo.git | https://host/owner/repo.git → owner:repo
    SEGMENTS="$(printf '%s' "$REMOTE" | sed -E 's#^[a-zA-Z]+://[^/]+/##; s#^[^/]+:##; s#\.git$##')"
    case "$SEGMENTS" in
      */*) SEGMENTS="$(printf '%s' "$SEGMENTS" | awk -F/ '{print $(NF-1)"/"$NF}')" ;;
    esac
    [ -n "$SEGMENTS" ] && PROJECT_KEY="$(printf '%s' "$SEGMENTS" | tr '/' ':')"
  fi
fi
[ -n "$PROJECT_KEY" ] || PROJECT_KEY="$(basename "$PROJECT_DIR")"

# ── Server reachable? ───────────────────────────────────────────────────────
# Local servers often publish no host ports (docker-network only). When the
# default localhost URL is unreachable and a SonarQube container exists, use
# its bridge IP — reachable from both the host and scanner containers placed
# on the same network (same trick as homelab-style setups).
SERVER_STATUS="$(json_get "$(api /api/system/status '')" server-status)"
case "$SONAR_HOST_URL" in
  http://localhost*|http://127.0.0.1*|https://localhost*|https://127.0.0.1*) IS_LOCAL=1 ;;
  *) IS_LOCAL=0 ;;
esac
if [ "$SERVER_STATUS" != "UP" ] && [ "$IS_LOCAL" -eq 1 ] && command -v docker >/dev/null 2>&1; then
  CONTAINER="${SONAR_CONTAINER:-sonarqube}"
  C_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$CONTAINER" 2>/dev/null | awk '{print $1}')"
  if [ -n "$C_IP" ]; then
    DISCOVERED_NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$CONTAINER" 2>/dev/null | awk '{print $1}')"
    info "$CONTAINER container found at $C_IP (network: ${DISCOVERED_NETWORK:-?}) — using http://$C_IP:9000"
    SONAR_HOST_URL="http://$C_IP:9000"
    SERVER_STATUS="$(json_get "$(api /api/system/status '')" server-status)"
  fi
fi
if [ "$SERVER_STATUS" != "UP" ]; then
  VERDICT="SKIPPED"; REASON="SonarQube server at $SONAR_HOST_URL not reachable (status: ${SERVER_STATUS:-none})"
  emit 2
fi
info "server $SONAR_HOST_URL is UP"

# ── Scanner detection ───────────────────────────────────────────────────────
props_has() { grep -qE "^[[:space:]]*$1[[:space:]]*=" "$PROJECT_DIR/sonar-project.properties" 2>/dev/null; }

find_scanner() {
  if [ -n "${SONAR_SCANNER_BIN:-}" ] && [ -x "${SONAR_SCANNER_BIN:-}" ]; then
    printf '%s' "$SONAR_SCANNER_BIN"; return 0
  fi
  command -v sonar-scanner >/dev/null 2>&1 && { printf 'sonar-scanner'; return 0; }
  command -v docker >/dev/null 2>&1 && { printf 'docker'; return 0; }
  return 1
}

run_scan() {  # run_scan <scanner args...> — scanner log lands in $SCAN_LOG
  SCANNER="$(find_scanner)" || { SCANNER=""; return 1; }
  if [ "$SCANNER" = "docker" ]; then
    # Reachability rules: join a discovered server network when auto-discovery
    # found one; on Linux --network=host reaches host-published local servers;
    # anything else (remote URL) uses the default bridge.
    declare -a NET_ARGS=()
    if [ -n "${SONAR_SCANNER_NETWORK:-}" ]; then
      NET_ARGS=(--network="$SONAR_SCANNER_NETWORK")
    elif [ -n "$DISCOVERED_NETWORK" ]; then
      NET_ARGS=(--network="$DISCOVERED_NETWORK")
    else
      case "$SONAR_HOST_URL" in
        http://localhost*|http://127.0.0.1*|https://localhost*|https://127.0.0.1*)
          [ "$(uname -s)" = "Linux" ] && NET_ARGS=(--network=host) ;;
      esac
    fi
    CACHE_DIR="${SONAR_SCANNER_CACHE:-${HOME}/.cache/sonarqube-scanner}"
    mkdir -p "$CACHE_DIR"
    docker run --rm --user "$(id -u):$(id -g)" ${NET_ARGS[@]+"${NET_ARGS[@]}"} \
      -v "$PROJECT_DIR:/usr/src" -v "$CACHE_DIR:/opt/sonar-scanner/.sonar" -w /usr/src \
      -e SONAR_HOST_URL="$SONAR_HOST_URL" -e SONAR_TOKEN -e SONAR_USER_HOME=/opt/sonar-scanner/.sonar \
      -e HOME=/tmp "${SONAR_SCANNER_IMAGE:-sonarsource/sonar-scanner-cli}" "$@"
  else
    (cd "$PROJECT_DIR" && "$SCANNER" "$@")
  fi
}

# ── Mode selection ──────────────────────────────────────────────────────────
DO_SCAN=1
case "$MODE" in
  scan) DO_SCAN=1 ;;
  api)  DO_SCAN=0 ;;
  off)  VERDICT="SKIPPED"; REASON="mode=off — SonarQube check disabled for this run"; emit 2 ;;
  auto)
    if find_scanner >/dev/null 2>&1; then
      DO_SCAN=1
    else
      DO_SCAN=0
      info "no sonar-scanner binary or docker — api mode (last stored analysis only)"
    fi ;;
  *) printf 'sonar-review: unknown mode: %s\n' "$MODE" >&2; exit 2 ;;
esac

# ── Scan + Compute Engine ───────────────────────────────────────────────────
if [ "$DO_SCAN" -eq 1 ]; then
  MODE_USED="scan"
  SCAN_LOG="$(mktemp "${TMPDIR:-/tmp}/sonar-review.XXXXXX")"
  trap 'rm -f "${SCAN_LOG:-}"' EXIT

  ARGS=("-Dsonar.projectKey=$PROJECT_KEY" "-Dsonar.projectName=$PROJECT_KEY")
  if [ -n "${SONAR_ORG:-}" ]; then ARGS+=("-Dsonar.organization=$SONAR_ORG"); fi
  # Exclusions only when the properties file does not define its own: the file
  # wins for keys it sets, the command line fills the rest.
  if ! props_has sonar.exclusions; then
    ARGS+=("-Dsonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/target/**,**/.git/**,**/.venv/**,**/venv/**,**/__pycache__/**,**/vendor/**,**/coverage/**,**/*.min.js,**/*.min.css")
  fi
  # Java full analysis needs compiled bytecode; use it when it exists.
  for candidate in target/classes build/classes/java/main build/classes/kotlin/main; do
    if [ -d "$PROJECT_DIR/$candidate" ]; then
      ARGS+=("-Dsonar.java.binaries=$candidate"); break
    fi
  done
  # Coverage reports, when the test suite already produced one.
  for f in coverage/lcov.info htmlcov/lcov.info target/site/jacoco/jacoco.xml \
           build/reports/jacoco/test/jacocoTestReport.xml coverage.xml reports/coverage.xml; do
    if [ -f "$PROJECT_DIR/$f" ]; then
      case "$f" in
        *jacoco*) ARGS+=("-Dsonar.coverage.jacoco.xmlReportPaths=$f") ;;
        *coverage.xml) ARGS+=("-Dsonar.python.coverage_reportPaths=$f") ;;
        *) ARGS+=("-Dsonar.javascript.lcov.reportPaths=$f") ;;
      esac
      break
    fi
  done

  info "scanning ($PROJECT_KEY)..."
  if ! run_scan "${ARGS[@]}" >"$SCAN_LOG" 2>&1; then
    tail -5 "$SCAN_LOG" >&2 2>/dev/null || true
    VERDICT="ERROR"; REASON="scanner run failed — see the log lines above"
    emit 3
  fi

  # The gate only exists once the Compute Engine processed the report.
  TASK_ID="$(grep -oE 'api/ce/task\?id=[0-9a-fA-F-]+' "$SCAN_LOG" | tail -1 | cut -d= -f2 || true)"
  if [ -n "$TASK_ID" ]; then
    info "waiting for the Compute Engine (task $TASK_ID)..."
    waited=0
    CE=""
    while [ "$waited" -lt "$TIMEOUT" ]; do
      CE="$(json_get "$(api /api/ce/task "id=$TASK_ID")" ce-status)"
      case "$CE" in SUCCESS|FAILED|CANCELED) break ;; esac
      sleep 3; waited=$((waited + 3))
    done
    if [ "$CE" != "SUCCESS" ]; then
      VERDICT="ERROR"; REASON="Compute Engine did not finish SUCCESS (status: ${CE:-timeout after ${TIMEOUT}s})"
      emit 3
    fi
  else
    info "no CE task id in the scanner log — polling the gate directly"
  fi
else
  MODE_USED="api"
  info "api mode: reading the last stored analysis (no new scan)"
fi

# ── Quality gate verdict ────────────────────────────────────────────────────
info "waiting for the Quality Gate..."
waited=0
GATE_STATUS=""
while [ "$waited" -lt "$TIMEOUT" ]; do
  GATE="$(api /api/qualitygates/project_status "projectKey=$PROJECT_KEY")"
  GATE_STATUS="$(json_get "$GATE" gate-status)"
  case "$GATE_STATUS" in OK|ERROR|PASSED|FAILED) break ;; esac
  # API-level error (unknown project, bad token…): the server answered.
  if printf '%s' "$GATE" | grep -q '"errors"'; then
    MSG="$(json_get "$GATE" api-error)"
    VERDICT="ERROR"; REASON="SonarQube API: ${MSG:-unexpected error response} — check the token and that the project has been analyzed at least once"
    emit 3
  fi
  sleep 5; waited=$((waited + 5))
done
case "$GATE_STATUS" in
  OK|PASSED)
    VERDICT="PASS"; REASON="quality gate passed (mode: $MODE_USED)"
    emit 0
    ;;
  ERROR|FAILED)
    FAILED_CONDITIONS="$(json_get "$GATE" gate-failed)"
    VERDICT="FAILED"; REASON="quality gate failed (mode: $MODE_USED)"
    emit 1
    ;;
  *)
    VERDICT="ERROR"; REASON="could not read the gate within ${TIMEOUT}s (last status: ${GATE_STATUS:-none})"
    emit 3
    ;;
esac
