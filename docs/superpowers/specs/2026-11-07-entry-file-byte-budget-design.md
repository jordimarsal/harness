# Design: byte budget for the agent entry point

**Date:** 2026-11-07
**Status:** Draft (Spec Gate — pending maintainer review)
**Source:** review of [mattabate/life-distributable](https://github.com/mattabate/life-distributable)
(2026-11-06), idea #4 of the batch that was not taken up in PR #6.

## 1. Problem

### 1.1 The entry file is loaded whole, and nothing stops it growing

Every session of a consumer project starts by reading its entry file —
`AGENTS.md` (opencode) or `CLAUDE.md` (claude). That file is billed as context
on **every** dispatch, including the implementer subagents a leader spawns, so
its size is a recurring cost, not a one-off.

Today `templates/AGENTS.md` is **9 478 bytes** and the rendered file is
**9 477 bytes** (measured: `6 793` of base + `2 684` of
`workflow/opencode/full.md`). It grew **+911 bytes in PR #6 alone**, when three
hard rules were added. Nothing fails when it crosses a line; the only limit is
noticing.

### 1.2 life-distributable solved exactly this with a test

Its `preamble_test.go` fails the build when the preamble passes **12 000
bytes**. The budget is a number in a test, so growth is a review event: the
diff shows a size assertion moving, and the author has to decide in that
commit whether the new line is worth the bytes.

We have **no size assertion anywhere** — `grep -rn "wc -c\|bytes" tests/`
returns nothing.

### 1.3 What actually lands in the entry file

| tool | composed from | measured (worst case) |
|---|---|---|
| opencode | `templates/AGENTS.md` base **+** `workflow/opencode/{full,hybrid}.md` | **9 477 B** (full) · 9 433 B (hybrid) |
| claude | `templates/stacks/<stack>/CLAUDE.md.tpl` **+** `workflow/claude/{full,hybrid}.md` | **6 700 B** (python + hybrid) |

Component sizes today: `AGENTS.md` 9 478 · `workflow/claude/hybrid.md` 3 399 ·
`workflow/claude/full.md` 2 812 · `workflow/opencode/full.md` 2 684 ·
`workflow/opencode/hybrid.md` 2 640 · stack templates 2 092 (node) … 5 022
(python).

`render_workflow` (`init.sh`) swaps only the text between
`<!-- harness:workflow:start -->` and `<!-- harness:workflow:end -->`; the
`harness:project` block is preserved from the previous install. So both
composition and preservation affect the final size, and only the installed file
is the honest measure.

## 2. Decision

### 2.1 One hard budget on the installed file: 12 000 bytes

A new `test_entry_file_byte_budget` installs the two worst cases and asserts
the entry file never exceeds **12 000 bytes**:

| install | file asserted | today |
|---|---|---|
| `--tool=opencode` (full workflow) | `AGENTS.md` | 9 477 B → **27 % headroom** |
| `--tool=claude --workflow=hybrid` + python stack | `CLAUDE.md` | 6 700 B |

12 000 B is life-distributable's number — roughly 3 k tokens — and it is
deliberately *not* tuned to today's size: it is a round ceiling that growth
runs into, not a ratchet that fires on the next added line.

The failure message states the budget, the measured size, the overage, and the
two legitimate ways out:

```
FAIL: AGENTS.md is 12 431 B (budget 12 000 B, +431)
      Trim it (move detail into docs/ and link from §2) or raise the budget
      in this same commit with a one-line justification.
```

Raising the budget must be a visible line in the diff — that is the whole
point. The comment above the constant says so explicitly, so nobody "fixes" a
red build by deleting the assertion.

### 2.2 Component budgets, so the failure names the file

The installed file alone cannot say *which* component grew, and a stack
template that is not in the rendered pair (java, rust, android, …) would never
be measured at all. So the same test also asserts, with `wc -c` and no install:

| component | budget | today (max) |
|---|---|---|
| `templates/AGENTS.md` | 11 000 | 9 478 |
| `templates/workflow/*/*.md` | 4 500 | 3 399 |
| `templates/stacks/*/CLAUDE.md.tpl` | 7 000 | 5 022 |

These are looser than §2.1 on purpose: they exist to *name* a runaway file,
while the installed-file budget is the binding constraint. Every one of the 11
component files is covered regardless of which stack gets rendered.

### 2.3 Why a test and not a review rule

A rule in `docs/` constrains the person who reads it; a test constrains the
commit. The failure mode this guards against is not malice — it is a
well-meaning PR that adds "just one more hard rule" every time, which is
precisely how `AGENTS.md` gained 911 bytes in a single PR.

## 3. Discarded alternatives

- **Budget only the source files.** Cheaper, but misses the composition: a
  stack template and a workflow block can each be under budget while their sum
  is not, and it measures something the model never reads.
- **Budget all 7 stacks × 2 workflows rendered** (14 installs). Complete, but
  §2.2 already covers component size deterministically, and the rendered pair
  in §2.1 is the worst case for each tool. Fourteen installs buy nothing the
  other two assertions do not.
- **Token count instead of bytes.** Tokens are the real cost, but they depend
  on the tokenizer, are not comparable across models, and `wc -c` is available
  everywhere the suite already runs. Bytes are the proxy; the budget is coarse
  enough that the proxy's error does not matter.
- **Fail on growth over the *current* size (a ratchet).** Would fire on every
  legitimate addition, including the one that fixed a real gap, and would train
  people to raise the number without thinking. A round ceiling has a meaning
  ("entry files stay under 12 k") that a ratchet does not.

## 4. Out of scope

- Rewriting `AGENTS.md` for size — if a future PR wants to trim it, that is its
  own change; this spec only makes the cost visible.
- `docs/` files (`specs.md`, `verification.md`, `conventions.md`) — read on
  demand (progressive disclosure), not loaded at session start.
- The `harness:project` block a consumer appends: it is theirs, it is outside
  the harness's control, and the budget applies to the harness-shipped file.

## 5. Verification

- `npm test` ≥ **571 PASS / 0 FAIL** (baseline `54322ea`: 571 / 0; the test
  adds 11 component assertions + 2 rendered assertions + 1 install each).
- `tests/test-security.sh` 12/12; `shellcheck` on the CI list clean.
- Mutation proof required: add a filler line to `templates/AGENTS.md` until the
  installed file crosses 12 000 B and confirm the test goes red **and** the
  message names the file; restore byte-identical (md5).
