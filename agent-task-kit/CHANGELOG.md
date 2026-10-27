# Changelog

## 0.1.2 — 2026-10-27

- Moved to `jordimarsal/harness` (public) as `agent-task-kit/` — the kit's
  permanent home. Installable from a clean clone.
- README translated to English (repository convention) and rewritten for the
  new location: install from a `git clone`, no workspace-relative paths.
- `CHECKLIST.md` no longer references the private protocol document by path.
- No changes to `CHECKLIST.md` content, the command, or the skill (still 0.1.1).

## 0.1.1 — 2026-10-20

- `CHECKLIST.md` is now the operational runbook: quick path, git and check
  commands, phase prompts, and a prompt-log template.
- Added untracked-file detection and `git status --short -- tests/`; documented
  safe git undo and the limits of `git diff HEAD`.
- Clarified that existing tests are immutable; new tests are allowed only when
  the prompt asks for them.
- Aligned the prompts with the drill: cases, EARS, logging, post-mortem,
  `check.sh` and README reconciliation.
- Added a commit path (`git add -p`, staged diff, commit, inspect) for formats
  that require commits.

## 0.1.0 — 2026-10-20

- Initial kit: human checklist, `/task-protocol` command and
  `delegated-task-discipline` skill.
- Extracted from `../AI-AGENT-TASK-PROTOCOL.md` after the Yaba drill.
- Smoke test: a subagent loaded the skill, produced a 3-line plan and waited for
  approval; no files were written.
