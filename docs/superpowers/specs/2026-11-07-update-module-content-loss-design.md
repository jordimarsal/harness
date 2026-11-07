# Design: `--update` must not drop module-injected content

**Date:** 2026-11-07
**Status:** Draft (Spec Gate — pending maintainer review)
**Source:** discovered while updating `debrief-mcp` from `v0.10.3-1-g271c75b`
to `v0.10.5` (2026-11-07); recorded as `FOLLOW-UPS.md` §10. Not caused by
PRs #5/#6/#7 — the defect is pre-existing.

## 1. Problem

`--update` finished with `exit 0` and every `check_file` green, and had
silently deleted content that modules had appended to shared files.

### 1.1 What happened

`debrief-mcp` declares five modules in `harness/feature_list.json`
(`decision-memory`, `security-audit`, `vertical-slices`, `architecture-catalog`,
`gauntlet`). After a plain `install.sh --update`:

| file | lost |
|---|---|
| `docs/verification.md` | the whole `security-audit` checklist block — **82 lines** (`A01`…`A05`) |
| `harness/CHECKPOINTS.md` | checkpoints **C7 — Audit** and **C8 — Gauntlet** — **15 lines** |

Neither file was in the backup: `init.sh` only backs up `AGENTS.md`/`CLAUDE.md`
when they differ beyond the managed blocks, and `docs/verification.md`/
`docs/specs.md` when they differ from the template — module blocks were
appended *after* those checks, so the pre-update copies were not preserved.
Git had them; a consumer without a commit would not.

### 1.2 Root cause

Four lines, one story:

1. **`init.sh:176`** — on `--update`, the stored module list is read with a
   *line-scoped* sed:
   `s/.*"modules"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p`. It only matches
   when `"modules": [...]` sits on a **single line**. A pretty-printed array
   (any `json.dumps(..., indent=2)`, which an agent does routinely to
   `feature_list.json`) yields nothing → `MODULES_FLAG` empty →
   `MODULES_SELECTED` empty (the `else` branch at `init.sh:390` prints
   *"no optional modules installed"* only when interactive; in a non-TTY run
   it says nothing at all).
2. **`init.sh:1012` and `init.sh:1080`** — `docs/verification.md` and
   `harness/CHECKPOINTS.md` are copied from the templates **unconditionally**,
   wiping the appended blocks.
3. **`init.sh:1162`** — re-injection runs only `if [ "${#MODULES_SELECTED[@]}" -gt 0 ]`.
   It does not run, so nothing is put back. No error, no warning, `exit 0`.
4. **`init.sh:914-917`** — the write side (`refresh_project_metadata`) makes
   the same line-scoped assumption. Its guard only checks that the key
   `"modules"` exists, which it does on any line, so the `warn` at line 917 is
   unreachable for this shape: the substitution silently does nothing.

Reproduced with a minimal fixture — `json.dumps({"project": {"modules":
["security-audit", "gauntlet"]}}, indent=2)` → the sed returns empty. It is not
a `debrief-mcp` quirk: **any** multi-line array hits it.

### 1.3 Why the suite is green

`test_update_flow` installs with `--modules=decision-memory` and then asserts
that the array is still *present* in `feature_list.json` — never that the
module content was re-injected. The assertions it does make
(`harness/decisions/_template.md`, `AGENTS.md`) are all satisfied by files the
first install created and that nothing deletes. The gap is exactly the class
`life-distributable` #130 describes: the doc/gate pair agrees with itself and
both disagree with the behaviour.

## 2. Decision

### 2.1 Read and write `modules` as JSON, not as a line

`python3` is already a guarded dependency of `init.sh` (lines 150, 632, 946,
1287 — `entry_differs_beyond_workflow` refuses to run without it). Add one
helper and use it for both directions:

```bash
feature_list_modules()   # echo the declared modules, comma-separated
refresh_modules_field()  # write the selection back, whatever the file's shape
```

Both are `python3 -c` over `json.load` / `json.dump(..., indent=2)`; when
`python3` is missing they keep today's line-scoped sed and `warn`, so the
degradation is the current behaviour rather than a hard failure.

The read fixes the data loss (step 1.2.1). The write makes `refresh_project_metadata`
honest (step 1.2.4): with a multi-line array it now actually records the
selection instead of pretending to.

Re-serialising with `indent=2` normalises a file an agent had already
pretty-printed; `audit_level` and `workflow` keep their single-line seds
(`init.sh:919`, `init.sh:924`) because a scalar value is always on one line
regardless of indentation.

### 2.2 Warn when a copy would destroy a block that will not come back

The read fix covers every module *declared* in `feature_list.json`. One case
remains: a block present in the file for a module that is **not** declared
(hand-added, or removed from `feature_list` by hand). That is legitimately not
re-injected, but losing it silently is not.

Before each unconditional `cp` of a file that can carry module markers
(`docs/verification.md`, `harness/CHECKPOINTS.md`), scan the existing file for
`<!-- harness:module:<name>:start -->`; for every name absent from
`MODULES_SELECTED`, `warn` naming the module and the file. Loud, cheap, and it
turns any residual case of §1.2 into a message instead of a disappearance.

### 2.3 Tests

**`test_update_reinjects_modules`** — the regression test:

1. install with `--modules=security-audit,gauntlet`;
2. assert `harness:module:security-audit:start` in `docs/verification.md` and
   `harness:module:audit-checkpoint:start` in `harness/CHECKPOINTS.md`;
3. **reformat** `harness/feature_list.json` with
   `python3 -c 'json.dump(json.load(...), indent=2)'` — the trigger;
4. run `--update`;
5. assert both markers are still there, and that `docs/verification.md` is
   byte-identical to the pre-update copy.

Step 3 is what makes the test fail on today's code: without it the array is
already on one line and the bug never fires.

**`test_update_warns_on_undeclared_module_block`** — install with
`security-audit`, delete `"security-audit"` from the array by hand, run
`--update`, assert the log names the module and the file.

Both assertions are about *content surviving*, not about the log line: a test
that only grepped for a warning would pass while data still vanished.

### 2.4 Release

`CHANGELOG.md` entry + patch bump `v0.10.5` → `v0.10.6` (`install.sh` REF and
`package.json`), house pattern — and **tag it**: `test_release_ref_tagged`
(PR #7) now fails on any bump whose tag is missing, which is how this class of
problem reached `debrief-mcp` in the first place.

## 3. Discarded alternatives

- **Only warn, don't fix the read.** Loud failure is better than silence, but
  the warning would fire on every `--update` of a pretty-printed project while
  the content was still lost. Warning is the belt; the read fix is the
  suspenders.
- **Parse `feature_list.json` with sed/awk multi-line.** Possible, and it would
  avoid the `python3` dependency — but `json.load` cannot get nesting or quoting
  wrong, and the dependency already exists and is already guarded.
- **Stop overwriting the two files; append instead.** `--force` must be able to
  reset a module section to the shipped text, so the copy has to stay. The
  injection that follows it is what makes the copy safe — it just has to run.
- **Preserve blocks by splicing them back after the copy.** Same effect as §2.1
  for declared modules, but it would also resurrect blocks the project stopped
  declaring, which is what `--remove-modules` exists to remove.

## 4. Out of scope

- `harness/backup/` has no `.gitignore` entry, so backups show up as `??` in a
  consumer's `git status`. Separate one-line fix, separate commit.
- The `audit_level`/`workflow` seds — correct as they are (single-line scalars).
- `--force` re-asking for modules in a non-TTY run (`init.sh:390`): a
  deliberate "reinstall from scratch" semantic, covered by §2.2's warning if it
  would drop anything.
- Restoring `debrief-mcp`'s content — already done during the investigation
  (`--update --modules=…`); both files verified byte-identical to `HEAD`.

## 5. Verification

- `npm test` ≥ **573 PASS / 0 FAIL** (baseline `54322ea`: 571 / 0, +2 tests).
- `tests/test-security.sh` 12/12; `shellcheck` on the CI list clean.
- Mutation proof required: revert `feature_list_modules()` to the line-scoped
  sed and confirm `test_update_reinjects_modules` goes red — otherwise the test
  is not looking at the bug.
- Repro fixture from §1.2 must be green after the change.
