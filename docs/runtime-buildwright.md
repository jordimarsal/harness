# External runtime: buildwright

[buildwright](https://github.com/jordimarsal/buildwright) ([PyPI](https://pypi.org/project/buildwright/))
is a standalone, unattended **host** for this protocol — a third interpreter of
the same artifacts, next to the OpenCode and Claude Code agents:

- OpenCode / Claude Code: interactive, human drives each step.
- buildwright: batch/unattended, the protocol drives; humans approve at the gates.

## Contract

buildwright installs **nothing** into target projects. The interface is the
artifacts only: `harness/feature_list.json` (protocol v1, schema-validated),
`harness/specs/`, `harness/progress/`, `CHECKPOINTS.md`, `APPROVAL`.
Source of truth for specs remains markdown; runtime-specific tuning (command
allowlist, timeouts, role→model overrides) lives in an optional project-owned
`harness/runtime.yaml`.

## Phase 0 (shipped, 0.2.0)

```bash
uv tool install buildwright
cd <your-harness-project>
buildwright harness status
```

Read-only: validates `harness/feature_list.json` and renders the feature board
plus the planned role→model routing.

## Next phases (design)

`buildwright harness run` — unattended implement→verify→review cycles per
feature in a git worktree, with hard gates where this protocol has scripts
(`init.sh`, `check-traceability.py`, `audit-security.sh`) and human gates via
interrupt/checkpoint. Full design:
[buildwright/docs/specs/2026-10-27-harness-runtime-design.md](https://github.com/jordimarsal/buildwright/blob/main/docs/specs/2026-10-27-harness-runtime-design.md).
