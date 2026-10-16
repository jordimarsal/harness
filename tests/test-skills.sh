#!/usr/bin/env bash
# tests/test-skills.sh — validació genèrica de tots els skills/ del repo
#
# Usage: ./tests/test-skills.sh
# Per cada skill (directori amb SKILL.md): frontmatter vàlid (name == directori,
# minúscules-guions ≤64), descripció ≤1024 caràcters, SKILL.md < 500 línies,
# totes les referències `references/*.md` citades existeixen, i tots els
# scripts Python compilen. Independent del contingut: aplica a skills futurs.

set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

PASS=0
FAIL=0
FAILED_NAMES=()

ok() {  # ok <nom>
  PASS=$((PASS + 1)); echo "    ok: $1"
}
ko() {  # ko <nom> <detall>
  FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1")
  echo "    FAIL: $1 — $2"
}

if [ ! -d "$SKILLS_DIR" ]; then
  echo "test-skills: no skills/ directory — nothing to validate"
  exit 0
fi

for dir in "$SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  dirname="$(basename "$dir")"
  skill_md="$dir/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    ko "$dirname/SKILL.md" "missing SKILL.md"
    continue
  fi

  name=$(sed -n 's/^name: //p' "$skill_md" | head -1)
  desc=$(sed -n 's/^description: //p' "$skill_md" | head -1)

  if [ -n "$name" ] && [ "$name" = "$dirname" ]; then
    ok "$dirname: name == directori"
  else
    ko "$dirname: name" "frontmatter name='$name' ≠ directori '$dirname'"
  fi

  if printf '%s' "$name" | grep -qE '^[a-z0-9-]+$' && [ "${#name}" -le 64 ]; then
    ok "$dirname: nom vàlid (minúscules-guions, ≤64)"
  else
    ko "$dirname: nom" "charset o longitud invàlids: '$name'"
  fi

  desclen=${#desc}
  if [ "$desclen" -gt 0 ] && [ "$desclen" -le 1024 ]; then
    ok "$dirname: descripció ≤1024 ($desclen)"
  else
    ko "$dirname: descripció" "longitud=$desclen"
  fi

  lines=$(wc -l < "$skill_md")
  if [ "$lines" -lt 500 ]; then
    ok "$dirname: SKILL.md < 500 línies ($lines)"
  else
    ko "$dirname: SKILL.md" "$lines línies"
  fi

  mapfile -t refs < <(grep -o 'references/[a-zA-Z0-9._/-]*\.md' "$skill_md" | sort -u)
  for ref in "${refs[@]}"; do
    if [ -f "$dir/$ref" ]; then
      ok "$dirname: referència $ref"
    else
      ko "$dirname: referència" "$ref citada però absent"
    fi
  done

  if [ -d "$dir/scripts" ]; then
    pys=$(find "$dir/scripts" -name '*.py' -type f)
    if [ -z "$pys" ]; then
      ok "$dirname: scripts/ buit"
    else
      compile_fail=0
      for py in $pys; do
        if ! python3 -m py_compile "$py" 2>/dev/null; then
          compile_fail=1
          ko "$dirname: script" "$py no compila"
        fi
      done
      [ "$compile_fail" -eq 0 ] && ok "$dirname: scripts compilen"
    fi
  fi
done

# ── Resum ───────────────────────────────────────────────────────────────────
echo ""
echo "test-skills: $PASS pass, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  printf '    failed: %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
