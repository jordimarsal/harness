# Design: traceability exemptions as recorded data

**Date:** 2026-11-07
**Status:** Draft (Spec Gate — pending maintainer review)
**Source:** review of [mattabate/life-distributable](https://github.com/mattabate/life-distributable)
(2026-11-06), idea #5 — listed as out-of-scope in
`2026-11-06-agent-tooling-hygiene-design.md` §4.

## 1. Problem

### 1.1 Some requirements cannot have a passing test — and the checker has no channel for that

`templates/docs/verification.md` (Level 4) is absolute:

> A feature cannot be marked as done until every requirement has a passing test
> that proves it works.

`templates/docs/specs.md` §Traceability repeats it:

> **Every R\<n\> must map to exactly one test and at least one implementation artifact.**

Real specs contain requirements that no test can verify: "the CLI shall print
usage on `--help`" checked only by inspection, a documentation requirement, a
manual-migration step, an external-service behaviour that cannot run in CI.
For those, a project has exactly three ways out today, and all are bad:

| option | consequence |
|---|---|
| leave the requirement unmapped | `check-traceability.py` reports a gap **forever** — the checker exits 1 on every run, the verdict stops meaning anything, and reviewers learn to ignore it (alarm fatigue) |
| invent a test identifier | the mapping lies; or a vacuous test is written to satisfy the identifier check |
| edit the checker / docs | fork drift — the project's process no longer matches the shipped one |

None of them records *why* the requirement is untested, or who decided it.

### 1.2 The information already has a home: the table's Status column

The traceability table (`specs.md` §Traceability) is four columns —
`| Requirement | Test(s) | Implementation file(s) | Status |` — and the checker
already parses Status (`ROW_RE` group 4 → `statuses`, `check-traceability.py`
§`_merge_impl_table`). Status is per-requirement, lives in the reviewed spec
artifact, and reaches the Completion Gate reviewer. It is the natural place for
an exemption to be *recorded as data* — but today any Status other than `done`
only lands the requirement in `unresolved` (informational); the gap logic never
consults it, and there is no way to say "no test, deliberately, for this
reason".

## 2. Decision

### 2.1 `exempt: <reason>` in the Status cell

A traceability-table row whose Status cell matches `^exempt\b`
(case-insensitive) declares its requirement exempt from the test mapping:

```markdown
| Requirement | Test(s)         | Implementation file(s) | Status                     |
|-------------|-----------------|------------------------|----------------------------|
| R1          | test_empty_cart | core/service.py        | done                       |
| R7          | —               | docs/install.md        | exempt: doc-only, checked at review |
```

Rules, in the order `check_feature()` applies them:

1. **The reason is mandatory.** `exempt` with no reason is still a gap, with a
   message that states the fix:
   `status is 'exempt' but carries no reason — write 'exempt: <why>'`.
   Without this the cell becomes a one-word escape hatch; with it, the
   cheapest way out still costs a sentence a reviewer can reject.
2. **The row must exist.** An exemption is a row, not an absence — the
   requirement is still visible in the reviewed table, and the Completion Gate
   reviewer confirms it (unchanged `specs.md` rule). A requirement absent from
   every table remains a plain gap.
3. **Exempt requirements produce no gap** (that is the point) and are **removed
   from `unresolved`** — a made decision is not an open one. Everything else
   (missing table row, missing test identifier) behaves exactly as today.
4. **The declaration wins.** A row marked exempt is reported exempt even if its
   Test(s) cell lists identifiers — under-claiming coverage is safe; the
   alternative would make exemption conditional on test existence, which is
   more code for a case nobody needs.

### 2.2 Output

The per-feature dict gains one field:

```python
{"name", "requirements", "covered", "exempted": [{"requirement": "R7", "reason": "…"}], "gaps", "unresolved"}
```

- `covered` keeps its meaning — *has a passing test* — so exempt requirements
  are **not** counted in it. `covered + len(exempted) ≤ requirements`.
- Text mode prints one line per exemption, in the gap line's style, so a
  reviewer skimming the checker output sees the decisions, not only the
  failures:
  `  [EXEMPT] R7: doc-only, checked at review`
  and the header gains a count when non-zero:
  `## feat-a: 3/4 requirements covered, 1 exempt`.
- Verdict logic is untouched: `PASS` iff no gaps. Exemptions never fail a run —
  they make an intentional state expressible so the gate can stay red for
  *actual* problems.
- `--json` change is additive (protocol v1 keeps its first fields); `docs/protocol.md`
  §5 documents the new field. This spec and the doc change land in the same PR —
  and if `2026-11-07-protocol-json-contract-test-design.md` is merged first, its
  doc↔`--json` test makes forgetting the doc change impossible (red build).

### 2.3 Docs reconciled in the same PR

An exemption channel the docs contradict is just a quieter fork. Both rules get
an exemption clause, stated with their existing force:

- `templates/docs/specs.md` §Traceability — after the "exactly one test" rule:
  a requirement with no verifiable test is exempt only by a table row
  `Status: exempt: <reason>`; the reviewer confirms each exemption at the
  Completion Gate; an exempt requirement is not counted as covered.
- `templates/docs/verification.md` Level 4 — the "every requirement has a
  passing test" sentence gains the same exception, and the example row.

### 2.4 Tests

**`test_traceability_exemption`** — installs, builds the fixture feature
(R1 covered, R2 gap, R3 exempt with reason) and asserts, in one test:

1. exit **0** (today: exit 1 — R3's exemption is not expressible);
2. text output names R3 under `[EXEMPT]` with its reason, and the header shows
   `1 exempt`;
3. `--json`: `exempted == [{"requirement": "R3", "reason": "…"}]`,
   `gaps == []`, `unresolved == []` (R3 out), `covered == 1`,
   `requirements == 3`, `verdict == "PASS"`;
4. a second run where R3's status is bare `exempt` (no reason) → exit **1**,
   text names R3 with the write-`exempt: <why>` message.

Assertion 4 is the mutation-proof companion: it fails if someone "simplifies"
the reason requirement away.

## 3. Discarded alternatives

- **Exemptions in `harness/feature_list.json`.** It is project data with a
  validated schema (`validate-feature-list.py`), and requirements belong to the
  spec, not the project section. It would also split one requirement's state
  across two files.
- **A separate `harness/specs/<feature>/exemptions.(md|json)`.** A second
  source of truth for state the table already carries; the table is what the
  reviewer reads at the gate, so an exemption anywhere else gets out of sync
  with it.
- **A checker flag (`--allow-uncovered=R7`).** Data in the invocation: lost
  between sessions, invisible in any reviewed artifact, and it moves the
  decision from the spec to whoever runs the command.
- **`Status: exempt` without a reason.** Cheaper to write and worthless to
  review — the whole value is the recorded why.
- **Counting exempt as covered.** Coverage is "has a passing test"; an exempt
  requirement has none. Reporting `4/4 covered` for a feature with an exemption
  would hide exactly the information this feature exists to surface.

## 4. Out of scope

- Per-test or partial exemptions ("this test is skipped in CI") — the Status
  cell speaks about the requirement, not individual tests.
- Exemption of implementation artifacts (the third column) — unchanged.
- Backfilling any existing project's tables.
- `--strict`/`--no-exemptions` modes — can be added later if a consumer asks;
  the JSON output already lets any wrapper filter on `exempted`.

## 5. Verification

- `npm test` ≥ **572 PASS / 0 FAIL** (baseline `54322ea`: 571 / 0; the new test
  adds ≥ 6 assertions in 1 test).
- `tests/test-security.sh` 12/12; `shellcheck` clean on the CI list (no shell
  changes expected — the checker is Python).
- Mutation proof required: comment out the exemption branch in `check_feature()`
  → assertion 1 goes red; drop the reason-mandatory rule → assertion 4 goes red.
- `docs/protocol.md` §5, `templates/docs/specs.md`, `templates/docs/verification.md`
  updated in the same PR (grep-able: `exempt` present in all three).
