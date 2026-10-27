#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$KIT_DIR/skills/delegated-task-discipline"
SKILL_DST="$HOME/.config/opencode/skills/delegated-task-discipline"
CMD_SRC="$KIT_DIR/commands/task-protocol.md"
CMD_DST="$HOME/.config/opencode/commands/task-protocol.md"

mkdir -p "$(dirname "$SKILL_DST")" "$(dirname "$CMD_DST")"

if [ -e "$SKILL_DST" ] && [ ! -L "$SKILL_DST" ]; then
    echo "Refusing to replace $SKILL_DST: it exists and is not a symlink." >&2
    echo "Move it away, then run this script again." >&2
    exit 1
fi

ln -sfn "$SKILL_SRC" "$SKILL_DST"

python3 - "$CMD_SRC" "$CMD_DST" "$KIT_DIR" <<'PY'
from pathlib import Path
import sys

src, dst, kit_dir = sys.argv[1:4]
text = Path(src).read_text()
Path(dst).write_text(text.replace("{{KIT_DIR}}", kit_dir))
PY

echo "Installed:"
echo "  skill   $SKILL_DST -> $SKILL_SRC"
echo "  command $CMD_DST"
echo
echo "OpenCode reloads skills and commands automatically."
echo "Run /task-protocol in a session to start."
