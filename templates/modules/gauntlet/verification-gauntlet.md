## Gauntlet Gate (gauntlet module)

> Appended by the harness `gauntlet` module. The gauntlet runs once per
> feature, after the last implementer batch and before the Completion Gate.
> The two human gates stay mandatory — the gauntlet filters what reaches
> them, it never approves for them.

Run from the project root:

```bash
bash harness/tools/gauntlet.sh --feature <name>   # exit 0 = G1 PASS, 1 = REJECT, 2 = usage error
```

Then complete passes G2–G4 per `docs/gauntlet-protocol.md` and record the
verdict in `harness/progress/gauntlet_<name>.md` (four PASS lines, or the
Completion Gate request is rejected). Checkpoint **C8** in
`harness/CHECKPOINTS.md` reflects this rule.
