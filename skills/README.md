# skills/

Standalone, publishable skills packaged from harness's battle-tested process
content. Unlike `templates/` (files injected into installed repos by the
installer), everything here must be valid on its own: a `SKILL.md` with
`name`/`description` frontmatter, optional `references/`, optional `scripts/`.

| Skill | Extracted from | Status |
|---|---|---|
| `spec-driven-development` | `templates/docs/specs.md` + `templates/tools/check-traceability.py` | standalone, generalised paths (`.specs/`) |
| `agent-dispatch-discipline` | role definitions (`leader`/`implementer`/`reviewer`) + workflow batching rules | standalone, pure protocol (no scripts) |
| `adversarial-review-gauntlet` | `templates/modules/gauntlet/` (protocol + `gauntlet.sh`) | standalone, resolves the #1 checker as sibling |

Conventions:

- Skill name = directory name, lowercase-hyphen, ≤ 64 chars.
- `SKILL.md` < 500 lines; details go to `references/`, executables to
  `scripts/`.
- Scripts keep the protocol of their harness original (same exit codes, same
  JSON shape) so both versions stay diffable.
- Test every skill script from `tests/` — see `tests/test-skill-sdd.sh`.

Packaging for external marketplaces (zip per skill) is a build-script concern,
not a source concern: this directory is the source of truth.

## Funnel vs product policy

Skills here are **funnel**: derived from harness's MIT-published process
content, they ship free on the public registries (Anthropic, GitHub).
Block's `agent-skills` marketplace was archived in June 2026 and is gone.
as advertising for the harness itself. Original skills that were never part
of harness (e.g. the local-LLM server-ops skill from the private llama-slots
knowledge) are **product**: they live in the separate private
`skillworks` repository under a proprietary license and are sold through
paid marketplaces. Nothing proprietary is committed here — everything in
`skills/` is intentionally open.
