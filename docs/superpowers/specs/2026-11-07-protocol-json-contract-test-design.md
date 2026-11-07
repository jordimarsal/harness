# Design: a doc↔`--json` contract test for protocol §5

**Date:** 2026-11-07
**Status:** Draft (Spec Gate — pending maintainer review)
**Source:** review of [mattabate/life-distributable](https://github.com/mattabate/life-distributable)
(2026-11-06), idea #6 — "protocol fixtures generated from `--json` output" —
listed as out-of-scope in `2026-11-06-agent-tooling-hygiene-design.md` §4.

## 1. Problem

### 1.1 The same shape lives in three unlinked places

Every tool's `--json` output shape is written three times: in
`docs/protocol.md` §5 (the contract consumers read), in each tool's code, and —
for four of the six tools — hand-copied as `assert` lines inside
`tests/test-install.sh`. Nothing ties them together, so a field renamed in code
ships with a stale doc and green tests until a consumer hits it.

### 1.2 Measured coverage gaps at `54322ea`

| tool (§5 contract) | shape asserted by a test? |
|---|---|
| `audit-security.sh` | yes — `test_audit_json_output` |
| `bench.sh` | yes — `test_bench_json_output` |
| `gauntlet.sh` | **no test at all** — `--json` exists (emits at `gauntlet.sh:120-131`), §5 documents it, nothing asserts it |
| `scan.py` | one of **four** documented commands (`--summary` only; `--impact`, `--duplicates`, `--style` untested) |
| `validate-feature-list.py` | yes — valid-file case only |
| `check-traceability.py` | yes — FAIL case only |

The worst offender is the tool with the most safety-critical contract
(gauntlet's "verdict without evidence is a vacuous PASS") — precisely the one
with zero coverage.

### 1.3 The doc snippets cannot be consumed mechanically

The §5 blocks are deliberately illustrative, not JSON: `"PASS" | "REJECT"`
enums, `"..."` and `N` placeholders, `[...]` arrays — and one genuine
ambiguity, `"duplicates": {"name": [paths]}`, where `"name"` reads as a literal
key but is an example key of a dynamic map. So "just parse the doc" fails
today, which is why the asserts were hand-copied in the first place.

## 2. Decision

### 2.1 One test, doc as source of truth

New `test_protocol_json_contract` in `tests/test-install.sh`: **extract** every
documented contract from `docs/protocol.md` §5, **run** the real tools on a
fixture project, **compare** shapes. The doc is the contract; code and tests
follow it. No fixture files are committed — they would become a fourth place
holding the same shape.

### 2.2 Extraction (validated against the real doc)

- One contract per `### <tool> --json` heading: the fenced ` ```json ` block.
- `### scan.py --json` instead documents four bullet one-liners —
  `` - `--cmd [ARG]`: `{...}` `` — extracted the same way, with the argument
  (`--impact F`, `--style N`) part of the contract's key.
- **The extractor must assert it found 6 headings and 9 contracts.** A doc
  restructure or a new undocumented tool then fails loudly instead of silently
  comparing nothing.

### 2.3 Normalisation — four rules, all exercised against §5 as it ships

```python
s = re.sub(r'"[^"]*"(?:\s*\|\s*"[^"]*")+', first_alternative, s)  # "PASS" | "REJECT" → "PASS"
s = s.replace("true | false", "true")
s = re.sub(r'(\w+"\s*:\s*)N\b', r'\g<1>0', s)                    # "total_files": N → 0
s = s.replace("[...]", "[]").replace("[paths]", "[]").replace("{...}", "{}")
```

Every §5 snippet parses after this (`{...}` is already the doc's
opaque-object marker). One doc change is part of this spec: the ambiguous
`"duplicates": {"name": [paths]}` becomes `"duplicates": {"<name>": [...]}` —
`<name>` is the wildcard-key marker (§2.4), which makes the doc say what it
always meant.

### 2.4 Comparison semantics — shape, not values

Walking doc vs actual output:

- **dicts: exact key-set equality, both directions.** A field removed in code
  (`documented, missing in output`) and a field added without a doc update
  (`in output, not documented`) both fail — the second direction is what keeps
  the doc from rotting.
- **`<name>` keys are wildcards** for dynamic maps: exempt from key equality;
  when the actual map is non-empty, one real value is shape-checked against the
  wildcard's value.
- **arrays: element shape checked only when the actual array is non-empty**
  (`findings: []` on a clean audit is correct, not a drift). When non-empty,
  element 0 is compared recursively.
- **scalars: type check only.** Which verdict, stack or path a fixture produces
  is data, not contract.
- `{...}` requires "is an object" and nothing more.

A prototype of exactly these rules ran against §5 as it ships and all **9**
contracts: after the §2.3 doc fix, **9/9 match** the current tools' output —
the test lands green, and is proven non-vacuous by the mutation proof (§5).

### 2.5 Fixture: one project, nine invocations

One install covers every tool:

```
init.sh --tool=opencode --modules=security-audit,performance-benchmarks,project-scanner,gauntlet
+ requirements.txt (python stack) · core/{models,service}.py
+ harness/specs/feat-a/{requirements.md} + impl table + tests/test_cart.py
  (the test_traceability_checker fixture)
```

| invocation | exits | note |
|---|---|---|
| `audit-security.sh --json` | 0 | |
| `bench.sh --json` | 0 or 1 | REJECTs (`__uncompared__`) when there is nothing to compare — same shape |
| `gauntlet.sh --json --feature feat-b` | 1 | REJECT by design (no spec trio) — shape verified identical for PASS and REJECT (`gauntlet.sh` emits `checks`/`gaps` on both paths) |
| `scan.py --json --summary` | 0 | |
| `scan.py --json --impact core/service.py` | 0 | success path only (§4) |
| `scan.py --json --duplicates` | 0 | |
| `scan.py --json --style 1` | 0 | |
| `validate-feature-list.py --json …` | 0 | |
| `check-traceability.py --json --feature feat-a` | 1 | FAIL (R2 gap) — same documented shape |

Non-zero exits are expected contract behaviour, so the test tolerates them and
asserts on the emitted file — while the *existing* per-tool tests keep owning
exit codes and text mode.

### 2.6 What this test does not replace

The four existing shape tests stay: they assert deeper things by design
(`findings == []`, `results == []`, exact stack values). The contract test
owns exactly one concern — doc and output agree — and complements them.

## 3. Discarded alternatives

- **Commit fixtures generated from `--json` output** (the review idea, taken
  literally). The committed fixture becomes a third copy of the shape that can
  itself drift from both doc and code — the disease this spec treats. Comparing
  doc → live output needs no stored copy.
- **Top-level keys only.** Misses the drift that matters most: `findings`/
  `results`/`checks` element keys are where a rename breaks a consumer's
  script, and gauntlet has no other test to catch it.
- **Token-level diff** (normalise doc and output to sorted JSON and diff).
  Comparing text conflates formatting and value differences with shape
  differences; key-path comparison states each failure as one readable line.
- **A separate `tests/protocol-contract.py`.** One more file with path plumbing
  for something the suite's heredoc pattern already expresses; the comparison
  is ~70 lines, in line with the existing heredocs.

## 4. Out of scope

- **Error shapes.** Tools emit `{"tool", "protocol", "command", "error", …}` on
  failure paths (e.g. `scan.py --impact` on a missing file) — undocumented, and
  deliberately not covered here: §5 documents success contracts, and error
  behaviour is asserted via exit codes in the existing tests. Documenting error
  objects is its own (small, worthwhile) spec.
- Protocol v2 / versioning the shapes.
- Adding contracts for tools that have no `--json`.

## 5. Verification

- `npm test` ≥ **572 PASS / 0 FAIL** (baseline `54322ea`: 571 / 0) — 1 new test
  carrying ≥ 13 assertions (6 + 9 heading/contract counts, 9 comparisons, plus
  the extraction-completeness asserts).
- The doc fix of §2.3 applied in the same PR; with it the comparison is green
  **today** (prototype evidence: 9/9).
- Mutation proof required, one per direction:
  - rename a key in a tool's output (e.g. `regressions` → `failures`) → red on
    `documented, missing in output`;
  - add a field to a tool's output without touching §5 → red on
    `in output, not documented`;
  - delete the `### gauntlet.sh --json` heading → red on the extraction count
    (5 ≠ 6) — the loud-failure guarantee.
- `bash -n tests/test-install.sh`; `shellcheck` clean on the CI list.
- Interaction note: if `2026-11-07-traceability-exemption-design.md` merges
  first, its `exempted` field must land in §5 in that PR — this test then
  enforces that pair forever.
