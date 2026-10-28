# Changelog

## v0.10.1 — 2026-10-28

- **fix(security-audit)**: `audit-security.sh` now excludes `./.buildwright`
  from the bandit scan. Runtime worktrees created by
  [buildwright](https://github.com/jordimarsal/buildwright) live under
  `.buildwright/worktrees/` and each carries its own `.venv`, so bandit was
  flagging vendored dependencies (pytest et al.) as if they were this
  project's code — HIGH-severity findings that made the audit gate fail for
  the wrong reason.

## v0.10.0 — 2026-10-27

- **feat(kit)**: new top-level `agent-task-kit/` — a portable kit for
  human-led, timeboxed tasks with an AI coding agent (technical interviews,
  timed exercises, pair sessions). Three artifacts that reinforce each other:
  `CHECKLIST.md` (the lead's operational runbook: quick path, git/check
  commands, per-phase prompts), the `delegated-task-discipline` Agent Skill
  (the agent's working contract: one objective per prompt, plan before edits,
  small reviewed diffs, no test edits or new dependencies, evidence-based
  reporting, stop rules after two failures), and the `/task-protocol`
  OpenCode command that injects the checklist and sets the working agreement.
  Self-contained installer (`agent-task-kit/install.sh`): symlinks the skill
  into `~/.config/opencode/skills/` and writes the command; the skill is
  standard Agent Skills and also links into `~/.claude/skills` or
  `~/.agents/skills`. MIT.

## v0.9.0 — 2026-10-23

- **feat(modules)**: new optional `vertical-slices` module — cut user-facing
  features into ordered, independently gated vertical slices, walking
  skeleton first (S1 proves the shape end-to-end on the real stack). Each
  slice is a first-class feature with `part_of` set to its parent: full
  state machine and both human gates per slice, spec-lite trios (3–6
  requirements, 3–5 tasks, `design.md` only for new decisions), and demo
  evidence required at the slice's Completion Gate. `part_of` is now a
  documented feature property, enforced by `validate-feature-list.py`
  (`unknown_part_of`); leader and spec-author absorb the mode conditionally
  on `docs/slicing-protocol.md`. Zero new states, zero new roles. Design:
  `docs/superpowers/specs/2026-10-23-vertical-slices-mode-design.md`.
- **feat(skills)**: new top-level `skills/` directory — standalone, publishable
  skills packaged from harness's process content (first entry:
  `spec-driven-development`). The skill generalises `templates/docs/specs.md`
  (EARS, 3-file specs, human gates) plus a standalone port of
  `check-traceability.py` (`.specs/` layout by default, `--specs-dir`,
  `--tests-dir` and repeatable `--impl-glob` for harness-managed repos; same
  protocol v1, exit codes and JSON shape). `tests/test-skill-sdd.sh` guards it
  against the frozen eval fixtures (01/02) and a portable-layout scenario;
  CI runs it as a new step.
- **feat(skills)**: second standalone skill `agent-dispatch-discipline` — the
  subagent orchestration protocol from the role definitions and workflow
  batching rules: one dispatch = one batch (2–4 tasks, never 5+), minimal
  dispatch anatomy, on-disk evidence checks after every batch, the
  "Nothing was written" re-dispatch opener, fresh-session restarts at ~70%
  context, and the file-first reply contract. Pure protocol (no scripts);
  validated by the new generic `tests/test-skills.sh`, which enforces
  SKILL.md frontmatter/size/reference/script validity for every skill in
  `skills/` — future skills are covered without per-skill test scaffolding.
- **feat(skills)**: third standalone skill `adversarial-review-gauntlet` —
  the sequential adversarial review (G1 correctness → G2 adversarial →
  G3 maintainability → G4 evidence) from the `gauntlet` module, with a
  generalised port of `gauntlet.sh`: specs default to `.specs/`, the
  traceability checker resolves via `--trace-tool`, the packaged sibling, or
  the `spec-driven-development` sibling skill, and missing checkers REJECT
  instead of passing vacuously. Same protocol v1 JSON and exit codes.
  `tests/test-skill-gauntlet.sh` covers PASS (sibling + explicit tool),
  REJECT paths (unchecked task, incomplete trio, traceability gap, missing
  checker), usage guards, and the frozen fixture 01 (no trio → no vacuous
  PASS).
- **docs(traceability)**: `skills/spec-driven-development/references/
  traceability.md` documents the test-identifier forms the checker actually
  resolves (bare name, JS/TS title, `path::name` node id) — the dotted
  `auth_test.R1` shape in the old `specs.md` example table does not resolve
  and misled readers.

## v0.8.2 — 2026-10-15

- **chore(rename)**: `harness-standard` → `harness`. GitHub repo renamed
  (old URLs redirect), badge text and assets updated (width 210 → 148),
  `HARNESS.md` and the `commit-msg` hook marker now read "harness". Back-compat:
  `--update` recognizes both the old and new `HARNESS.md` marker and both hook
  markers, so existing installs refresh cleanly without backup noise. The
  installed contract (`harness/`, `HARNESS.md`) and the SonarQube project key
  (`jordimarsal:harness-standard`) are unchanged.

## v0.8.1 — 2026-10-12

- **feat(gauntlet)**: new `gauntlet` module plus `--gauntlet` install shortcut —
  a sequential adversarial review (G1 correctness → G2 adversarial → G3
  maintainability → G4 evidence) that runs once per feature before the
  Completion Gate. `harness/tools/gauntlet.sh --feature <name>` enforces the
  mechanical G1 subset (spec trio, tasks all `[x]`, traceability without gaps;
  exit 2 on vacuous invocations), the verdict lands in
  `harness/progress/gauntlet_<name>.md`, and checkpoint **C8** hooks both the
  reviewer (full) and the review mode (hybrid). `--gauntlet` composes with
  `--hybrid`: one in-session agent plays the four passes sequentially with
  per-pass evidence logs. Human gates unchanged.
- **tests**: new `test_gauntlet_module` (`--gauntlet` + `--modules=gauntlet`
  + `--hybrid` compose, C8 injection/removal, `gauntlet.sh` PASS/REJECT/usage
  guards and `--json` protocol v1).
- **fix(performance-benchmarks)**: baseline-comparison gate in `bench.sh` no
  longer inverted — removed the `!` before `python3 - … <<'PYEOF'`; python exits
  0 on no-regressions so the success branch now sets `COMPARED=1` and the else
  branch sets `REJECT=1`. The bug rejected clean runs and accepted regressed ones;
  downstream ggufbench had already applied this fix locally.

## v0.8.0 — 2026-10-09

- **feat(uv)**: Python installs use [uv](https://docs.astral.sh/uv/) by
  default — `uv run pytest tests` / `uv build` are rendered into the tool
  config whenever uv is on PATH (no `uv.lock` required anymore). New `--no-uv`
  flag keeps the plain `python3 -m pytest` commands; without uv the installer
  warns and falls back instead of writing commands that would fail. The
  Python conventions template documents uv as the default toolchain
  (`uv add` / `uv sync` / `uv run`, commit `uv.lock`).
- **feat(commits)**: every install — any tool, any workflow, `--hybrid`
  included — enforces Conventional Commits. `templates/tools/commit-msg` is
  copied to `harness/tools/` and wired as the repo's `commit-msg` hook
  (recognized by its header marker and refreshed on reinstall; a pre-existing
  foreign hook is never touched; non-git projects get the docs only). The rule
  is documented in a new `## Commit Rules` conventions section, in
  `AGENTS.md` hard rules, and in the claude workflow templates (full +
  hybrid). `HARNESS.md` records whether the hook is enforced.
- **feat(conventions)**: `docs/conventions.md` now ships a stack-agnostic
  `## Design Principles` minimum bar in every install: semantic types (enum /
  DTO / VO / dataclass) over loose dictionaries, one concept per class and one
  responsibility per method, no nested try/catch, composition over
  inheritance, immutability (final fields, unmodifiable collections), and
  tell-don't-ask with rich value objects. Language sections may add rules,
  never subtract these.
- **tests**: new `test_python_uv_default` (uv default + `--no-uv` override
  with a stubbed uv) and `test_conventional_commits` (hook in git repos,
  rejected/accepted subjects, merge bypass, foreign hook preserved across
  `--update`, docs in opencode + `--hybrid` claude installs); `test_python_stack`
  now runs with a uv-free PATH so the fallback is asserted deterministically.

## v0.7.3 — 2026-10-08

- **fix(tools)**: `check-traceability.py` no longer reports a vacuous PASS.
  Three hard guards now exit 2 with a clear stderr message: a root that is
  not a directory (a bare `harness/feature_list.json` positional is a `--root`
  and used to pass 0/0 silently), an `--feature` name without
  `requirements.md`, and a requested feature that parses zero requirements.
  A verdict without per-feature `## <name>: n/n` lines can no longer happen.
  JS test support ported as well: `_search_tests_dir` now matches `test()/it()`
  titles in `tests/**/*.js` (node:test) in addition to Python stems/functions —
  node-based projects no longer fail traceability with "identifier not found".
- **docs(workflow)**: the `hybrid.md` review-mode step (claude + opencode)
  documents the correct invocation (`--feature <name>` / `--all`) and warns
  about vacuous PASSes; adds the relative-assertion rule for suite tests
  (`indexOf`/existence instead of global manifest positions or counts).
- **tests**: new `tests/test-traceability.sh` covering the three guards, the
  happy path with a generated fixture, and the workflow documentation greps.

## v0.7.2 — 2026-10-07

- **fix(quality)**: all 12 SonarQube issues resolved. The template tools
  (`check-traceability.py`, `validate-feature-list.py`, project-scanner
  `scan.py`) are refactored into single-purpose helpers — behaviour verified
  against the frozen `evals-fixtures/` corpus (PASS/FAIL unchanged) — and
  `bin/init.js` now invokes `/bin/bash` by absolute path instead of resolving
  it through a potentially writable `$PATH`.
- **fix(tests)**: the backup-path assertion uses `find` instead of `ls`
  (ShellCheck SC2012).
- **docs(quality)**: SonarQube metrics published on GitHub Pages — quality
  page with the raw scan report (`docs/quality/`) and static README badges,
  refreshed after each scan with `scripts/sonar-quality.py`.

## v0.7.1 — 2026-10-06

- **fix(updates)**: blank-line runs around the managed blocks (workflow,
  project) no longer read as a customization — a real heredoc append next to a
  template with a leading blank line used to trigger a spurious backup.

## v0.7.0 — 2026-10-06

- **Project block (`harness:project`)**: the entry file (`CLAUDE.md` /
  `AGENTS.md`) ends with a marked, project-owned block. `--update`/`--force`
  preserve its content verbatim when regenerating the file, and the collision
  comparison ignores it — project-specific mandatory steps and map rows live
  in the auto-loaded entry file without turning routine updates into backup
  noise.

## v0.6.0 — 2026-10-06

- **Hybrid workflow (`--hybrid`, `--workflow=full|hybrid`)**: the same SDD
  discipline and both human gates, executed by one in-session agent — roles
  become modes, and evidence logs (`harness/logs/<feature>/batch-<n>.log`)
  plus the objective traceability check replace the independent reviewer.
  The workflow section of the entry file (`AGENTS.md` / `CLAUDE.md`) is now a
  marked, re-renderable block (`templates/workflow/<tool>/{full,hybrid}.md`);
  the choice persists in `harness/feature_list.json` (`project.workflow`) and
  `--update` re-applies it. Escalation rules back to the full dispatch flow
  are documented in the entry file and `docs/specs.md`.

## v0.5.0 — 2026-10-06

- **Collision backup (`--backup[=DIR]`)**: installing into a project that
  already owns files the harness would write (`AGENTS.md`, `CLAUDE.md`,
  `opencode.json`, `.claude/settings.json`, `docs/specs.md`,
  `docs/verification.md`, `HARNESS.md`, agents dirs, module copies) no longer
  hard-refuses or silently clobbers. The installer lists the collisions and,
  on a TTY, asks to move them aside; non-interactive installs require
  `--backup`. Colliding files are **moved — never deleted —** to
  `harness/backup/<UTC>/` preserving their relative paths, and the install
  summary lists them for manual merge-back. Detection is tool-aware (an
  existing `AGENTS.md` does not collide with a claude install).
  `--force`/`--update` now back up replaced files that differ from the
  templates instead of `rm -f`-ing them (closes the destructive gap on
  customized entry files, configs and agent roles; an untouched project
  creates no backup noise), and a tool switch still cleans the previous
  tool's files. The refusal check is now `harness/`-only; foreign
  `.claude/`/`.opencode/` content no longer blocks a fresh install.
- Fresh installs now default to `v0.5.0` (installer REF pin); `package.json`
  version aligned to the release.

## v0.4.1 — 2026-10-06

- **README badge suggestion**: on success, the installer prints the
  canonical raw-URL badge snippet only when `README.md` exists without a
  "built with harness-standard" badge — and never writes into the file
  (README is user-owned). Idempotent across `--update`: once the badge is
  added, no re-suggestion. No README, no suggestion.
- Fresh installs now default to `v0.4.1` (installer REF pin); `package.json`
  version aligned to the release.

## v0.4.0 — 2026-10-06

- **`clarity` module** (optional): 80% ASD-STE100 response style —
  short active sentences, one term one meaning, no filler. Installs
  `docs/clarity-style.md`. References: Karpathy 2026-10-02
  (`https://x.com/karpathy/status/2105819303471976479`) and Kun Chen
  reply 2026-10-02
  (`https://x.com/kunchenguid/status/2105931853815296295`). Subset
  mined from the last 10 local opencode sessions.
- **Brand badge**: terminal-style SVG asset (`assets/badge.svg`, 210x20 —
  traffic lights + `built with | harness-standard` in prompt green on
  near-black, mono type) plus a light-theme variant (`assets/badge-light.svg`,
  warm paper segments and darker signal greens for contrast). README
  documents canonical usage and the theme-adaptive swap pattern.
- **uv-managed Python + polyglot gates**: `init-verify.sh` runs pytest
  through `uv` when `pyproject.toml` + `uv.lock` exist and runs the
  `web/` subproject suite alongside the root one; the Python-stack
  `TEST_CMD` in `opencode.json` follows the same detection.
- **`check-traceability` fixes**: identifiers containing `::` are exact
  node ids (`tests/path/file.py::test_name`) instead of silently gapping;
  `--all` skips features whose status is not `done` (no impl table yet is
  not a gap).
- **Lint-clean tools**: `validate-feature-list.py` and
  `check-traceability.py` pass a strict ruff config (line-length 100,
  isort) so refreshed projects keep their quality gates green.
- **Templates**: batching hard rule, one-batch-at-a-time workflow step and
  §4 Batching subsection in `AGENTS.md`; *size for batches* rule in
  `docs/specs.md`; two reviewer anti-patterns in `docs/verification.md`
  (trusting a subagent's "done" claim; reading the test count under
  `addopts='-q'`). Upstreamed from real usage (tenda).
- **README**: new maintainer-facing "Releasing" section — the four-step
  release ritual (CHANGELOG heading, REF/package.json bump + commit, annotated
  tag, `gh release create` from the CHANGELOG section). A pushed tag alone
  never shows on the Releases page.
- Fresh installs now default to `v0.4.0` (installer REF pin); `package.json`
  version aligned to the release.

## v0.3.0 — 2026-10-04

- **Per-language conventions**: `docs/conventions.md` is now assembled from the
  detected stack's language conventions (java, python, typescript, node,
  android, rust, generic) — the old frame shipped Java rules to every stack.
  The universal frame stays single-source; language sections are
  marker-delimited chunks.
- **Selectable architectures**: `--architecture=<name>` (layered, hexagonal,
  clean, cqrs, microservices, modular-monolith, event-driven — the directory
  is the catalog) renders `docs/architecture.md` and injects an
  architecture conventions section into `docs/conventions.md`; recorded in
  `project.architecture`. Interactive picker at fresh install on a TTY.
  Installer-generated docs self-heal on update; edited docs are untouched.
- **Modules at any time**: `--update --add-modules=a,b` and
  `--update --remove-modules=a,b` — removal deletes copied files, strips
  marked sections (including the C7 audit checkpoint when no audit module
  remains) and updates `project.modules`. Spec:
  `docs/superpowers/specs/2026-10-04-architectures-language-conventions-modules-design.md`.
- Fresh installs now default to `v0.3.0` (installer REF pin); `package.json`
  version aligned to the release.

## v0.2.0 — 2026-10-04

- **Log archiving** (token-cost discipline): command output over ~20 lines
  (tests, builds, failing gates) goes to `harness/logs/<feature>/T<n>.log`;
  chat and progress files keep only the path plus a short excerpt. The
  reviewer reads big logs surgically (`grep -n`, `sed -n`) instead of
  end-to-end; the leader never pastes outputs into dispatch prompts.
- **`log-reader` module** (optional): delegates big-log reading to a cheap
  read-only subagent and verifies its quoted evidence against the original;
  on verification failure it falls back to reading the exact ranges with the
  main model. Installs `docs/log-reader-protocol.md`; leader and reviewer
  pick it up as a conditional capability.
- **README**: new "Cost discipline" and "Optional modules" sections; the
  uninstall snippet now also removes `docs/log-reader-protocol.md`.
- **Version stamp + `--update`**: every install records its harness version in
  `harness/feature_list.json` (`project.harness_version`) and `HARNESS.md`.
  New `--update` mode: detects the installed version and tool, re-applies the
  stored modules and audit level without flags (fixing the `--force` footgun
  that silently dropped them), and refreshes harness-managed files while
  preserving user state. `install.sh --ref=latest` resolves the newest tag;
  `--update` defaults to it. First update-capable release is the one that
  ships this change.
- Fresh installs now default to `v0.2.0` (installer REF pin); `package.json`
  version aligned to the release.
- **Feature retro line**: when a feature closes, the summary moved to
  `harness/progress/history.md` carries `retro: <n> dispatches · <s> stalls ·
  <r> restarts` — the per-feature efficiency record that shows where process
  friction accumulates.
- **Batch discipline** in the subagent prompts: the implementer is dispatched
  **2–4 consecutive tasks per batch** (1 when a single task is large, 4 only for
  small clones, never 5+), never a whole feature. It writes files before any
  prose, runs the quality gates after every task, only then marks `[x]`, and
  answers with one line `done <batch> -> harness/progress/impl_<name>.md`
  pointing at a file that exists (created on the first batch if missing).
- **Leader**: new *implementer batch sizing* table (2–3 default / 1 large / 4
  clones / never 5+), on-disk verification after every batch instead of trusting
  chat claims, stall recovery (`Nothing was written: … Create <first file> now.`)
  and a fresh-session rule once a session nears its context limit — a session
  that fills its context stops working silently and returns nothing.
- **Spec author**: sizes each `T<n>` so batches of 2–4 land green on their own.
- **Reviewer**: states that it executes every command itself, reads test bodies
  (an import-only test covers nothing), and reviews the whole feature in one
  pass — batches are an implementer-side discipline.
- Applied to all four roles in both flavors (`templates/.opencode/agent/` and
  `templates/.claude/agents/`); the installed copies in an existing project
  need the same edit (the installer only writes on install).

## v0.1.1 — 2026-09-24

- Non-interactive installs are silent: with no TTY (curl pipes, CI, `</dev/null`)
  the installer skips all three prompts and uses defaults — tool `claude`,
  no optional modules, audit level `basic`. Pass `--tool=`, `--modules=`,
  `--audit-level=` to choose explicitly. Before this fix a piped install died
  at the first prompt (exit 1) and printed menu theatre into the log.
- `HARNESS_FORCE_TTY=1` forces the interactive prompts (used by the test suite).

## v0.1.0 — 2026-09-22

First public release.

- Remote one-command install:
  `curl -fsSL https://jordimp.net/harness/install.sh | bash -s -- --tool=claude`
  (or `--tool=opencode`).
- `--tool=` picks the driver: `claude` (CLAUDE.md + `.claude/`) or `opencode`
  (AGENTS.md + `.opencode/`).
- Requires `git` (the installer clones this repo shallowly).
- Installer detects the stack, copies roles/conventions/gates, writes `HARNESS.md`.
- Four roles (Leader / Spec Author / Implementer / Reviewer) for Claude Code and opencode.
- 7 stacks: TypeScript, Node.js, Java, Python, Android, Rust, Generic.
- Uninstall: `rm -rf CLAUDE.md AGENTS.md opencode.json .claude .opencode harness docs/architecture.md docs/conventions.md docs/specs.md docs/verification.md`
  (see README).
