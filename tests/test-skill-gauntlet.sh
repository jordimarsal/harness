#!/usr/bin/env bash
# tests/test-skill-gauntlet.sh — Guards de skills/adversarial-review-gauntlet
#
# Usage: ./tests/test-skill-gauntlet.sh
# Verifica que el port de gauntlet.sh (a) fa PASS sobre un fixture net amb
# resolució de checker germana i amb --trace-tool, (b) REJECTA tasca sense
# [x], spec trio incomplet, gap de traçabilitat i checker absent, (c) refusa
# PASS buits i arguments desconeguts amb exit 2, (d) manté el protocol v1
# --json, i (e) REJECTA un fixture congelat sense trio (anti-fals PASS).

set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$REPO_DIR/skills/adversarial-review-gauntlet/scripts/gauntlet.sh"
CHECKER="$REPO_DIR/skills/spec-driven-development/scripts/check_traceability.py"
FX1="$REPO_DIR/evals-fixtures/01-traceability-clean/project"

PASS=0
FAIL=0
FAILED_NAMES=()
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ok() {  # ok <nom>
  PASS=$((PASS + 1)); echo "    ok: $1"
}
ko() {  # ko <nom> <detall>
  FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1")
  echo "    FAIL: $1 — $2"
}

build_repo() {  # build_repo <dir> — fixture net: trio + [x] + traçabilitat verda
  local rep="$1"
  mkdir -p "$rep/.specs/login" "$rep/tests"
  cat > "$rep/.specs/login/requirements.md" <<'EOF'
# Requirements: login

## R1
The system shall reject the 5th consecutive failed attempt.

## R2
When credentials are valid, the system shall issue a token.
EOF
  printf '# Design: login\n\n- Files: src/auth.py\n' > "$rep/.specs/login/design.md"
  cat > "$rep/.specs/login/tasks.md" <<'EOF'
# Tasks: login

- [x] T1: Failure counter
      depends_on: (none)
      refs: R1

- [x] T2: Token issuance
      depends_on: (none)
      refs: R2
EOF
  cat > "$rep/.specs/login/traceability.md" <<'EOF'
| Requirement | Test(s) | Implementation file(s) | Status |
|-------------|---------|------------------------|--------|
| R1          | test_R1 | src/auth.py            | done   |
| R2          | test_R2 | src/auth.py            | done   |
EOF
  printf 'def test_R1():\n    assert True\n\ndef test_R2():\n    assert True\n' \
    > "$rep/tests/test_auth.py"
}

# ── (a) PASS amb resolució de checker germana (sense --trace-tool) ──────────
REP="$TMP_ROOT/repo-a"; build_repo "$REP"
out=$(cd "$REP" && bash "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "feature login: PASS" && \
   echo "$out" | grep -q "traceability:ok"; then
  ok "PASS amb checker germana (resolució automàtica)"
else
  ko "PASS checker germana" "exit=$code out=$out"
fi

# ── (b) PASS amb --trace-tool explícit ──────────────────────────────────────
REP="$TMP_ROOT/repo-b"; build_repo "$REP"
out=$(cd "$REP" && bash "$TOOL" --feature login --trace-tool "$CHECKER" 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "feature login: PASS"; then
  ok "PASS amb --trace-tool explícit"
else
  ko "PASS --trace-tool" "exit=$code out=$out"
fi

# ── (c) protocol v1 --json ──────────────────────────────────────────────────
REP="$TMP_ROOT/repo-c"; build_repo "$REP"
out=$(cd "$REP" && bash "$TOOL" --feature login --json 2>&1)
code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '"tool": "gauntlet"' && \
   printf '%s' "$out" | grep -q '"verdict": "PASS"' && \
   printf '%s' "$out" | grep -q '"name": "traceability", "status": "ok"'; then
  ok "--json protocol v1 amb checks"
else
  ko "--json" "exit=$code out=$out"
fi

# ── (d) REJECT: tasca sense [x] ─────────────────────────────────────────────
REP="$TMP_ROOT/repo-d"; build_repo "$REP"
sed -i 's/- \[x\] T2/- [ ] T2/' "$REP/.specs/login/tasks.md"
out=$(cd "$REP" && bash "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "REJECT" && \
   echo "$out" | grep -q "1 of 2 tasks still"; then
  ok "REJECT per tasca sense [x]"
else
  ko "REJECT tasca pendent" "exit=$code out=$out"
fi

# ── (e) REJECT: spec trio incomplet ─────────────────────────────────────────
REP="$TMP_ROOT/repo-e"; build_repo "$REP"
rm "$REP/.specs/login/design.md"
out=$(cd "$REP" && bash "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "missing spec file.*design.md"; then
  ok "REJECT per trio incomplet (design.md absent)"
else
  ko "REJECT trio incomplet" "exit=$code out=$out"
fi

# ── (f) REJECT: gap de traçabilitat ─────────────────────────────────────────
REP="$TMP_ROOT/repo-f"; build_repo "$REP"
sed -i 's/| test_R2 |/| test_inexistent |/' "$REP/.specs/login/traceability.md"
out=$(cd "$REP" && bash "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "traceability gaps"; then
  ok "REJECT per gap de traçabilitat"
else
  ko "REJECT traçabilitat" "exit=$code out=$out"
fi

# ── (g) REJECT: checker absent ──────────────────────────────────────────────
REP="$TMP_ROOT/repo-g"; build_repo "$REP"
out=$(cd "$REP" && bash "$TOOL" --feature login --trace-tool "$TMP_ROOT/no_hi_es.py" 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "traceability checker not found"; then
  ok "REJECT quan el checker no es troba (no PASS buit)"
else
  ko "REJECT checker absent" "exit=$code out=$out"
fi

# ── (h) ús: sense --feature -> exit 2 (refusa PASS buit) ────────────────────
out=$(bash "$TOOL" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "vacuous PASS"; then
  ok "sense --feature -> exit 2 amb avís de PASS buit"
else
  ko "sense --feature" "exit=$code out=$out"
fi

# ── (i) ús: argument desconegut -> exit 2 ───────────────────────────────────
out=$(bash "$TOOL" --feature x --no-existeix 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "unknown argument"; then
  ok "argument desconegut -> exit 2"
else
  ko "argument desconegut" "exit=$code out=$out"
fi

# ── (j) fixture congelat sense trio -> REJECT (mai PASS buit) ───────────────
out=$(cd "$FX1" && bash "$TOOL" --feature feat-a \
  --specs-dir harness/specs --trace-tool "$CHECKER" 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "missing spec file.*tasks.md"; then
  ok "fixture 01 sense tasks.md -> REJECT (no PASS buit)"
else
  ko "fixture sense trio" "exit=$code out=$out"
fi

# ── (k) --impl-glob: taules fora del directori de feature (layout harness) ──
REP="$TMP_ROOT/repo-k"
mkdir -p "$REP/harness/specs/login" "$REP/harness/progress" "$REP/tests"
cat > "$REP/harness/specs/login/requirements.md" <<'EOF'
# Requirements: login

## R1
The system shall reject the 5th consecutive failed attempt.
EOF
printf '# Design: login\n' > "$REP/harness/specs/login/design.md"
printf -- '- [x] T1: Failure counter\n      depends_on: (none)\n      refs: R1\n' \
  > "$REP/harness/specs/login/tasks.md"
printf '| R1 | test_R1 | src/auth.py | done |\n' \
  > "$REP/harness/progress/impl_login.md"
printf 'def test_R1():\n    assert True\n' > "$REP/tests/test_auth.py"
out=$(cd "$REP" && bash "$TOOL" --feature login \
  --specs-dir harness/specs --impl-glob 'harness/progress/impl_*.md' 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "feature login: PASS"; then
  ok "--impl-glob reenviat: PASS amb taules a harness/progress"
else
  ko "--impl-glob" "exit=$code out=$out"
fi

# ── Resum ───────────────────────────────────────────────────────────────────
echo ""
echo "test-skill-gauntlet: $PASS pass, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  printf '    failed: %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
