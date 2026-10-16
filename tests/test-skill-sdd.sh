#!/usr/bin/env bash
# tests/test-skill-sdd.sh — Guards de skill spec-driven-development
#
# Usage: ./tests/test-skill-sdd.sh
# Verifica que (a) el script standalone reprodueix els fixtures congelats
# (01 clean PASS, 02 gap FAIL amb R2), (b) funciona amb el layout portable
# .specs/ (taula dins del directori de feature, sense --impl-glob),
# (c) les files UNRESOLVED no fallen, (d) els errors d'ús retornen exit 2,
# (e) --all cobreix totes les features, i (f) el SKILL.md és vàlid
# (frontmatter, descripció ≤1024, referències presents, script compilable).

set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$REPO_DIR/skills/spec-driven-development/scripts/check_traceability.py"
SKILL_MD="$REPO_DIR/skills/spec-driven-development/SKILL.md"

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

FX1="$REPO_DIR/evals-fixtures/01-traceability-clean/project"
FX2="$REPO_DIR/evals-fixtures/02-traceability-gap/project"

# ── (a) fixture 01 (clean): exit 0 + verdict PASS ───────────────────────────
out=$(cd "$FX1" && python3 "$TOOL" --feature feat-a --json \
  --specs-dir harness/specs --impl-glob 'harness/progress/impl_*.md' 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q '"verdict": "PASS"'; then
  ok "fixture 01 clean -> exit 0 PASS (layout harness amb --impl-glob)"
else
  ko "fixture 01 clean" "exit=$code out=$out"
fi

# ── (a2) fixture 02 (gap): exit 1 + FAIL + gap R2 ───────────────────────────
out=$(cd "$FX2" && python3 "$TOOL" --feature feat-a --json \
  --specs-dir harness/specs --impl-glob 'harness/progress/impl_*.md' 2>&1)
code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q '"verdict": "FAIL"' && \
   echo "$out" | grep -q '"requirement": "R2"'; then
  ok "fixture 02 gap -> exit 1 FAIL (gap R2)"
else
  ko "fixture 02 gap" "exit=$code out=$out"
fi

# ── (a3) atribució pel nom de fitxer (impl_<feature>.md sense atribut) ──────
REP3="$TMP_ROOT/repo3"
mkdir -p "$REP3/harness/specs/login" "$REP3/harness/progress" "$REP3/tests"
printf '# Requirements: login\n\n## R1\nThe system shall reject the 5th attempt.\n' \
  > "$REP3/harness/specs/login/requirements.md"
printf '| R1 | test_R1 | src/auth.py | done |\n' \
  > "$REP3/harness/progress/impl_login.md"
printf 'def test_R1():\n    assert True\n' > "$REP3/tests/test_auth.py"
out=$(cd "$REP3" && python3 "$TOOL" --feature login \
  --specs-dir harness/specs --impl-glob 'harness/progress/impl_*.md' 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "VERDICT: PASS"; then
  ok "atribució impl_<feature>.md sense línia feature:"
else
  ko "atribució per nom de fitxer" "exit=$code out=$out"
fi

# ── (b) layout portable .specs: taula dins del directori de feature ─────────
REP="$TMP_ROOT/repo"
mkdir -p "$REP/.specs/login" "$REP/tests"
cat > "$REP/.specs/login/requirements.md" <<'EOF'
# Requirements: login

## R1
The system shall reject login attempts after 5 consecutive failures.

## R2
When the user submits valid credentials, the system shall issue a token.
EOF
cat > "$REP/.specs/login/tasks.md" <<'EOF'
# Tasks: login

- [ ] T1: Implement failure counter
      depends_on: (none)
      refs: R1
EOF
cat > "$REP/.specs/login/traceability.md" <<'EOF'
| Requirement | Test(s)          | Implementation file(s) | Status |
|-------------|------------------|------------------------|--------|
| R1          | test_R1          | src/auth/failure.py    | done   |
| R2          | test_R2          | src/auth/token.py      | done   |
EOF
cat > "$REP/tests/test_auth.py" <<'EOF'
def test_R1():
    assert True

def test_R2():
    assert True
EOF
out=$(cd "$REP" && python3 "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "VERDICT: PASS"; then
  ok "layout .specs (taula a traceability.md, tests per stem de funció)"
else
  ko "layout .specs" "exit=$code out=$out"
fi

# ── (c) UNRESOLVED no crea gap: status in_progress -> exit 0 ────────────────
sed -i 's/| done   |/| in_progress |/' "$REP/.specs/login/traceability.md"
out=$(cd "$REP" && python3 "$TOOL" --feature login 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "\[UNRESOLVED\] R1"; then
  ok "status in_progress -> exit 0 amb [UNRESOLVED]"
else
  ko "unresolved no gap" "exit=$code out=$out"
fi

# ── (d) errors d'ús: exit 2 ─────────────────────────────────────────────────
out=$(cd "$REP" && python3 "$TOOL" --feature no_existeix 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "unknown feature"; then
  ok "feature desconeguda -> exit 2"
else
  ko "feature desconeguda" "exit=$code out=$out"
fi

out=$(cd "$REP" && python3 "$TOOL" --feature login "$REP/package.json" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "root is not a directory"; then
  ok "root no-directori -> exit 2 amb pista"
else
  ko "root no-directori" "exit=$code out=$out"
fi

out=$(cd "$REP" && python3 "$TOOL" 2>&1)
code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -q "usage:"; then
  ok "sense --feature/--all -> exit 2 amb usage"
else
  ko "sense selector" "exit=$code out=$out"
fi

# ── (e) --all: descobreix les features del directori ────────────────────────
sed -i 's/| in_progress |/| done   |/' "$REP/.specs/login/traceability.md"
mkdir -p "$REP/.specs/logout" "$REP/tests"
cat > "$REP/.specs/logout/requirements.md" <<'EOF'
# Requirements: logout

## R1
When the user logs out, the system shall invalidate the token.
EOF
cat > "$REP/.specs/logout/traceability.md" <<'EOF'
| Requirement | Test(s)          | Implementation file(s) | Status |
|-------------|------------------|------------------------|--------|
| R1          | test_R2          | src/auth/logout.py     | done   |
EOF
out=$(cd "$REP" && python3 "$TOOL" --all 2>&1)
code=$?
if [ "$code" -eq 0 ] && echo "$out" | grep -q "## login:" && \
   echo "$out" | grep -q "## logout:"; then
  ok "--all descobreix totes les features"
else
  ko "--all" "exit=$code out=$out"
fi

# ── (f) validesa del SKILL.md i del paquet ──────────────────────────────────
SKILL_DIR="$REPO_DIR/skills/spec-driven-development"
name=$(sed -n 's/^name: //p' "$SKILL_MD" | head -1)
desc=$(sed -n 's/^description: //p' "$SKILL_MD" | head -1)
if [ "$name" = "spec-driven-development" ] && [ "$(basename "$SKILL_DIR")" = "$name" ]; then
  ok "frontmatter name == nom del directori"
else
  ko "frontmatter name" "name=$name"
fi
desclen=${#desc}
if [ "$desclen" -gt 0 ] && [ "$desclen" -le 1024 ]; then
  ok "descripció present i ≤ 1024 caràcters ($desclen)"
else
  ko "descripció" "longitud=$desclen"
fi
for ref in references/ears.md references/spec-files.md references/traceability.md; do
  if [ -f "$SKILL_DIR/$ref" ]; then
    ok "referència present: $ref"
  else
    ko "referència absent" "$ref"
  fi
done
if python3 -m py_compile "$TOOL" 2>/dev/null; then
  ok "check_traceability.py compila"
else
  ko "compilació" "py_compile va fallar"
fi
lines=$(wc -l < "$SKILL_MD")
if [ "$lines" -lt 500 ]; then
  ok "SKILL.md < 500 línies ($lines)"
else
  ko "SKILL.md massa llarg" "$lines línies"
fi

# ── Resum ───────────────────────────────────────────────────────────────────
echo ""
echo "test-skill-sdd: $PASS pass, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  printf '    failed: %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
