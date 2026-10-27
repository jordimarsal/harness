# Agent Task Kit

A portable kit for **human-led, timeboxed tasks with an AI coding agent** — the
shape of a technical interview, a timed exercise, or a pair-with-agent session.

It packages a repeatable protocol into three artifacts that reinforce each other:

| Artifact | For | What it does |
|---|---|---|
| `CHECKLIST.md` | You, the lead | Operational runbook: quick path, git/check commands, per-phase prompts. |
| `skills/delegated-task-discipline/` | The agent | Working contract: one objective per prompt, plan before edits, small diffs, evidence, stop rules. |
| `commands/task-protocol.md` | Both | The `/task-protocol` command starts the session, injects the checklist and sets the working agreement. |

## Why two artifacts (checklist + skill)

A skill is loaded by **the agent**, not by you. If the whole protocol lives
inside a skill, the agent reads the script while you lose the fast overview.
The kit separates the human runbook from the agent contract — and keeps them
saying the same thing.

The protocol is **human-led**: you own the gates and the decisions. The skill
does not make the agent autonomous; it makes it a disciplined implementer.

## Install

```bash
git clone https://github.com/jordimarsal/harness
cd harness/agent-task-kit
./install.sh
```

The script:

- symlinks the skill to `~/.config/opencode/skills/delegated-task-discipline`;
- writes the command to `~/.config/opencode/commands/task-protocol.md`, with the
  kit path substituted in.

OpenCode reloads skills and commands automatically. The skill is a symlink:
edits to the kit show up without reinstalling. The command is generated with
the kit path; if you edit it, run `./install.sh` again. `CHECKLIST.md` is read
on every invocation, so its changes are immediate.

The skill is standard Agent Skills: it can also be linked into `~/.claude/skills`
or `~/.agents/skills`. The command is OpenCode-specific; the checklist and the
skill are portable.

Manual install:

```bash
mkdir -p ~/.config/opencode/skills ~/.config/opencode/commands
ln -sfn "$PWD/skills/delegated-task-discipline" \
  ~/.config/opencode/skills/delegated-task-discipline
python3 - "$PWD/commands/task-protocol.md" \
  ~/.config/opencode/commands/task-protocol.md "$PWD" <<'PY'
from pathlib import Path
import sys
src, dst, kit = sys.argv[1:4]
Path(dst).write_text(Path(src).read_text().replace("{{KIT_DIR}}", kit))
PY
```

Uninstall:

```bash
rm ~/.config/opencode/skills/delegated-task-discipline
rm ~/.config/opencode/commands/task-protocol.md
```

## Usage

1. Open OpenCode in the task's repo.
2. Run `/task-protocol`.
3. Answer the three questions: repo, timebox, acceptance criteria.
4. Keep `CHECKLIST.md` open; tick the phases.
5. At the end, fill the post-mortem.

The command injects the checklist into the session. The agent loads the skill
and waits for your cue. If it doesn't activate on its own, mention
`@delegated-task-discipline`.

### Smoke test

1. `./install.sh`
2. `ls -l ~/.config/opencode/skills/delegated-task-discipline`
3. `grep -n 'CHECKLIST' ~/.config/opencode/commands/task-protocol.md`
4. In a session: `/task-protocol` → the checklist appears and the agent asks for
   repo, timebox and criteria before touching anything.

Tested 2026-10-20: a subagent loaded the skill, produced a 3-line plan and wrote
nothing until approved.

The command injects the checklist with a shell block (`cat`); it only reads the
local kit file.

## What "done" means

- Every diff reviewed; no existing test modified; no new dependency without a decision.
- Full suite + lint/typecheck green.
- Reconciliation against the source of truth (counts, sums, sample).
- A 30-second summary with residual risk.
- A post-mortem with **one** improvement.

## Evolving the kit

- Bump `metadata.version` in `skills/delegated-task-discipline/SKILL.md` and log
  it in [`CHANGELOG.md`](CHANGELOG.md).
- Change `CHECKLIST.md` and the skill together: a rule you check and the agent
  ignores is a bug.
- Test changes against your own sandbox drill before shipping.
- Keep the `description` concrete. It is the trigger; "AI-first" alone is too vague.
- Keep this folder generic — no interview-specific briefs or rubrics.
- To publish the skill standalone, copy the skill directory to the top-level
  [`skills/`](../skills/) collection and update the collection list in the
  README.

## Why the checklist is in English

It is the likely language of the session, and it keeps the vocabulary warm:
*gate, diff, spec, red test, reconcile, residual risk*. The rest of the docs
may be in your language; the checklist is not.

## Files

```text
agent-task-kit/
├── README.md
├── CHECKLIST.md
├── CHANGELOG.md
├── install.sh
├── commands/
│   └── task-protocol.md
└── skills/
    └── delegated-task-discipline/
        ├── SKILL.md
        ├── LICENSE.txt
        ├── references/
        │   ├── worker-rules.md
        │   ├── prompt-template.md
        │   └── review-checklist.md
        └── assets/
            └── report-template.md
```

## Origin

The protocol was authored as `AI-AGENT-TASK-PROTOCOL.md` in a private
interview-prep workspace and extracted into this kit after a timed drill. That
long-form document remains the reference; this repository is the kit's home.

## License

MIT — see `skills/delegated-task-discipline/LICENSE.txt`.
