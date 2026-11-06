# Design: scan.py — exclusion filter on project-relative paths

**Date:** 2026-11-06
**Status:** Approved (Spec Gate — maintainer, 2026-11-06)
**Source:** [issue #4](https://github.com/jordimarsal/harness/issues/4)
(mattabate, 2026-11-06): *scan.py skips every file when the root is under a
dir named build or env*.

## 1. Problem

`Scanner.scan` and `generic_summary` decide exclusions with

```python
if set(p.parts) & EXCLUDED_DIRS:      # scan.py:58
if p.is_file() and not (set(p.parts) & EXCLUDED_DIRS):   # scan.py:188
```

but `p` comes from `root.rglob(...)`, so `p.parts` contains the root's **own
name and every ancestor above it**. Any checkout whose path contains a
component equal to an `EXCLUDED_DIRS` entry — `build`, `env`, `venv`,
`dist`, `harness`, `node_modules`, … — makes the intersection non-empty for
**every** file, and the whole project is skipped silently.

Reproduced on this repo and on fixtures:

| Invocation | Result |
|---|---|
| `scan.py --root /tmp/…/build/app --summary` (has `pkg/a.py`) | `generic fallback - no Python files` / `(empty project)` |
| `scan.py --root /tmp/…/normal/app --summary` (has `pkg/b.py`) | `Total Python files: 1` |
| `scan.py --summary` run inside this repo (path contains `harness`) | `(empty project)` |

Blast radius — all four commands, all exit 0, no error anywhere:

- `--summary` falls through to `generic_summary`, which applies the same
  filter and therefore also reports `(empty project)`.
- `--duplicates` → `none`; `--style` → `(no Python files found)`.
- `--json --summary` → `{"stack": "generic", "total_files": 0, …}` — the
  machine interface lies with protocol v1 shape intact.
- `--impact F` → `error: file not found in project: F` (exit 0).

**Why no test caught it:** `tests/test-install.sh` builds projects at
`$TMP_ROOT/<name>` where `TMP_ROOT=/tmp/harness-test-XXXXXX` — no path
component equals an `EXCLUDED_DIRS` entry, so the buggy filter never fires
in CI.

The fix must preserve the *inner* exclusion — that is why `harness` is in
the list at all: an installed project contains `harness/tools/scan.py`,
which must stay uncounted.

## 2. Decision

Filter on the path **relative to the scan root** instead of the absolute
path — the issue's suggested fix, applied at both sites:

```python
# scan.py:58  (Scanner.scan)
if set(p.relative_to(self.root).parts) & EXCLUDED_DIRS:

# scan.py:188  (generic_summary)
if p.is_file() and not (set(p.relative_to(root).parts) & EXCLUDED_DIRS):
```

Semantics after the change:

- Ancestors **above** the root no longer participate: `--root …/build/app`
  scans normally, `--summary` run inside a repo cloned at `…/harness`
  scans normally.
- Directories **inside** the root are still excluded exactly as before:
  `<root>/build/`, `<root>/node_modules/`, `<root>/harness/` (the installed
  tools dir) are skipped.
- `relative_to` is total here: `rglob` only yields paths rooted at the
  scanned root, and `Path(".").parts == ()`, so a relative `--root .`,
  `--root app`, a trailing slash and `./app/../app` all resolve (verified).
- `--root project/build` (root itself inside an excluded name) now scans
  that directory: the operator asked for it explicitly.

### Files to change

| File | Change |
|---|---|
| `templates/modules/project-scanner/scan.py` | 2 lines: `p.relative_to(self.root)` / `p.relative_to(root)` before `.parts` |
| `tests/test-install.sh` | new `test_scan_excluded_ancestor` + registration in the runner list |
| `CHANGELOG.md` | `fix(scan)` entry (issue #4) |
| `install.sh`, `package.json` | patch bump `v0.10.3` → `v0.10.4` (house pattern: fix commits carry the release, cf. `030fe3f`, `f88ab6e`) |

`docs/superpowers/plans/2026-09-07-harness-modules.md:1013,1138` embeds the
old code — it is a dated historical plan, left untouched.

### Test: `test_scan_excluded_ancestor`

`new_project "build/scanner-excl"` (nested name works: `mkdir -p`), install
with `--modules=project-scanner`, seed `core/models.py` plus an inner
`build/gen.py`, then:

1. `--summary` lists `core/models.py` and does **not** print the
   `generic fallback` heading → covers `Scanner.scan`.
2. `--summary` does **not** list `gen.py` → inner exclusion preserved.
3. A sibling project under `$TMP_ROOT/build/` with no `.py` files but one
   `.md` reports `.md: 1 files` instead of `(empty project)` → covers
   `generic_summary`.
4. `--json --summary` on the Python fixture reports `"stack": "python"` and
   `total_files >= 1` → the machine interface no longer lies.

## 3. Discarded alternatives

- **`os.path.relpath(p, root)`** — works, but returns `..`-bearing strings
  that need re-splitting and fail soft on invariant violations.
  `relative_to` raises loudly if `rglob` ever stops being root-prefixed.
- **`p.resolve().relative_to(root.resolve())`** — resolves symlinks,
  changing the scanned layout, and costs one syscall per file for no
  benefit: `rglob` already yields root-prefixed paths.
- **Pruning walk (`os.walk` + `dirs[:]` filter)** — the *better* fix
  long-term (today `rglob` still descends into `.git/` and `node_modules/`
  only to discard every file), but it rewrites traversal and is a separate
  performance change with its own review.
- **Dropping `harness` / `env` from `EXCLUDED_DIRS`** — symptom-chasing;
  `build` and `dist` are equally plausible checkout names and the bug would
  remain for them.

## 4. Out of scope

- `--impact`/`--duplicates` exit codes (0 with an error line) — pre-existing
  contract question, issue #4 does not depend on it.
- Traversal pruning for excluded directories (see above).
- `docs/reference/annex.md` `ProjectReader` snippet — illustrative code with
  no exclusion filter at all; not executed.

## 5. Verification

- `bash tests/test-install.sh` green. Baseline at spec time: **523 PASS /
  0 FAIL** (65 tests, `271c75b`). After the change: 523 + the new test's
  assertions, still 0 FAIL.
- `bash tests/test-security.sh` green (unchanged code paths).
- Manual: `python3 templates/modules/project-scanner/scan.py --summary`
  inside this repo now reports its 8 Python files instead of
  `(empty project)`.
- Manual: `--root /tmp/…/build/app` and `--root /tmp/…/env/app` fixtures
  report their files; an inner `build/` fixture dir stays excluded.
