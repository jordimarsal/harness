# Design: vertical-slices module — feature-level incremental delivery

**Date:** 2026-10-23
**Status:** Approved (Spec Gate — maintainer, 2026-10-23)
**Source material:** Walking-skeleton / tracer-bullet practice (Cohn; The
Pragmatic Programmer) applied to the harness SDD loop: today every batch lands
green, but value only lands at the feature's Completion Gate. The front-loaded
spec trio and the end-of-feature review/gauntlet peak are the two costs this
design redistributes across smaller, independently gated increments.

## 1. Problem

Two costs of feature-level SDD:

1. **Value lands late.** Batches are increments *within* a feature ("every 2–4
   consecutive tasks must form a batch that lands with green gates on its own",
   `docs/specs.md`), but nothing user-visible is demoable until the feature
   completes. On a 12-task feature the first end-to-end proof arrives last.
2. **Ceremony peaks at the ends.** A full spec trio before any code, and a
   whole-feature review + gauntlet after all of it, concentrate effort where
   the feature is most rigid. Per unit of delivered value, both would be
   cheaper spread across small increments: lite specs per slice, small reviews
   per slice, no single big-bang gate.

The established "light" principle (zero new agent roles, zero new workflow
states — `2026-09-06-harness-modules-design.md` §2) rules out an epic/slice
state machine. The mechanism below adds none.

## 2. Decision

A slice **is** a feature. Zero new roles, zero new states, zero protocol
changes:

| # | Mechanism | Form |
|---|---|---|
| 1 | **vertical-slices module** (optional) | `templates/modules/vertical-slices/` → installs `docs/slicing-protocol.md`; leader and spec-author absorb it conditionally |
| 2 | **`part_of` field** (core) | optional documented property in `feature_list.json`; a slice is a first-class feature whose `part_of` names its parent feature |

### Why slices-as-features

- The state machine already serializes slices correctly: invariant I1 (at most
  one feature `in_progress`) makes slice n+1 start from what slice n left
  green — the existing batch rule, one level up.
- `check-traceability.py` is feature-keyed (protocol v1.1): per-slice
  traceability works with zero checker changes.
- Gates, reviewer scope ("the whole feature in one pass"), gauntlet scaling
  (Trivial → G1+G4) and the Wekan mirror all key on features: a slice
  inherits every control for free.

## 3. Module: vertical-slices

```
templates/modules/vertical-slices/
├── manifest.json
└── slicing-protocol.md          → docs/slicing-protocol.md (mode: copy)
```

Protocol contract (full text in the file):

- **When:** user-facing features spanning UI/API/persistence. Not
  infrastructure or library work, where no user-visible increment exists —
  those keep the classic flow.
- **Slice map:** before the first slice, the leader drafts and the human
  approves an ordered slice map, recorded as a `## Slice Map` section in the
  parent feature's `design.md` (`S<n> | name | user outcome | acceptance
  subset`) and gated by the parent's Spec Gate. The parent's trio is the map
  plus the cross-slice ADRs; the parent feature holds them so slices stay
  thin.
- **Walking skeleton:** S1 is the thinnest end-to-end path through the real
  architecture (UI → API → persistence), not a mock-up. Demoable value exists
  from the first Completion Gate.
- **Slice = feature:** each slice is an entry in `feature_list.json` with
  `part_of` set to the parent feature `name`, named `<parent>_<outcome>` so
  entries sort together. Full state machine and both gates per slice.
- **Slice spec lite:** per slice — 3–6 EARS requirements, 3–5 tasks,
  `design.md` only when the slice introduces a new ADR-worthy decision (one
  line + pointer to the parent otherwise). The lite spec is the point: spec
  effort moves from once-before-the-feature to per-increment.
- **Definition of done adds a demo:** a slice's Completion Gate requires a
  recorded demo command + observed output, end-to-end on the real stack. A
  slice whose acceptance cannot be demoed is a horizontal layer in disguise —
  re-cut it.
- **Parent status:** the parent feature is `in_progress` once its first slice
  enters implementation and `done` only when the last slice's Completion Gate
  passes.

Role absorption (conditional, keyed on `docs/slicing-protocol.md` existing):

- **leader** — Effort Scaling "Very complex" row becomes: split into slices
  (walking skeleton first), treat each slice as a feature, re-apply the table
  per slice.
- **spec-author** — drafts the slice map, then slice-lite trios; batch sizing
  rules (2–4 tasks, green on their own) unchanged *inside* a slice.

### Pairing note

Slices + the hybrid workflow is a pairing setup: one session per slice, the
slice contract approved at the start, the human reviewing diffs continuously,
the recorded demo as the Completion Gate. Gates become lighter and more
frequent — which is the point of slicing. The context-contamination risk that
hybrid's evidence controls compensate for is bounded by slice size: a thin
slice is cheap to redo.

## 4. `part_of` field (core)

`templates/feature_list.schema.json` gains one documented property on feature
items (`additionalProperties: true` already accepts it; this names it):

```json
"part_of": {"type": "string"}
```

`validate-feature-list.py` gains one rule: `part_of` must reference an
existing feature `name` (error code `unknown_part_of`). The state machine, the
protocol document and `check-traceability.py` are unchanged.

## 5. Out of scope

- **New states, new roles, epic objects.** The light principle: a parent
  feature + `part_of` children express the epic with what exists.
- **Checker aggregation (`--group <parent>`).** Per-slice reports cover the
  gate need; a grouped parent report is worth adding once real installs use
  slices.
- **`skills/spec-driven-development` slicing-guide reference.** The content
  ships with the module first; the funnel copy follows after #2039 merges
  (propagate to `pr-prep/` branches per `FOLLOW-UPS.md`).
- **Wekan grouping.** Slices are ordinary cards; board-level grouping is
  cosmetic and can wait.

## 6. Verification

- `tests/test-install.sh`: menu lists `vertical-slices`; auto-discovered
  manifest validates; a dedicated install test asserts
  `docs/slicing-protocol.md` lands and the module is recorded in
  `harness/feature_list.json` (`project.modules`).
- Validator test: `part_of` pointing at a missing feature name is rejected
  (`unknown_part_of`); pointing at a real one passes.
- Flavor sync: leader and spec-author conditional bullets identical in
  `.claude` and `.opencode` templates (frontmatter differences pre-existing).
- `bash tests/test-install.sh` and `bash tests/test-security.sh` green.
