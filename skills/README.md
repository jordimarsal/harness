# skills/

Standalone, publishable skills packaged from harness's battle-tested process
content. Unlike `templates/` (files injected into installed repos by the
installer), everything here must be valid on its own: a `SKILL.md` with
`name`/`description` frontmatter, optional `references/`, optional `scripts/`.

## The collection

| Skill | Extracted from | Notes |
|---|---|---|
| `spec-driven-development` | `templates/docs/specs.md` + `templates/tools/check-traceability.py` | EARS, 3-file specs, human gates; generalised checker (`.specs/`) |
| `agent-dispatch-discipline` | role definitions (`leader`/`implementer`/`reviewer`) + workflow batching rules | pure protocol, no scripts; + log-delegation reference |
| `adversarial-review-gauntlet` | `templates/modules/gauntlet/` (protocol + `gauntlet.sh`) | ships its own vendored checker via packaging |
| `architecture-advisor` | `templates/modules/architecture-catalog/` + `templates/architectures/` | 8-pattern catalog, 3 selectors, justification block |
| `clarity-style` | `templates/modules/clarity/` | single-file 80% ASD-STE100 reply style |
| `wekan-tasks` | `templates/modules/wekan-tickets/SKILL.md` | harness-native skill: mirrors SDD states on Wekan |

Install (see the README table of contents at the repo root):

```bash
npx skills add jordimarsal/harness --skill <name>
```

Channels: Anthropic `anthropics/skills` (PRs #2039, #2040 under review),
skills.sh leaderboard (install-counted), SkillsMP (auto-indexes this repo).

## Conventions

- Skill name = directory name, lowercase-hyphen, ≤ 64 chars.
- `SKILL.md` < 500 lines; details go to `references/`, executables to
  `scripts/`.
- Frontmatter carries `author`/`version`/`tags` next to `name`/`description`
  (marketplace metadata), plus the provenance footer linking back to harness.
- Scripts keep the protocol of their harness original (same exit codes, same
  JSON shape) so both versions stay diffable.
- Validated by `tests/test-skills.sh` (generic, applies to every skill here);
  skills with behavior get dedicated tests (`tests/test-skill-sdd.sh`,
  `tests/test-skill-gauntlet.sh`).

Packaging for external marketplaces (zip per skill) is a build-script concern,
not a source concern: this directory is the source of truth.

## Funnel vs product policy

Skills here are **funnel**: derived from harness's MIT-published process
content, they ship free on the public registries as advertising for the
harness itself. Original skills that were never part of harness (e.g. the
local-LLM server-ops skill from the private llama-slots knowledge) are
**product**: they live in the separate private `skillworks` repository under
a proprietary license and are sold through paid marketplaces. Nothing
proprietary is committed here — everything in `skills/` is intentionally
open. (Block's `agent-skills` marketplace was archived in June 2026 and is
gone.)
