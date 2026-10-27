# Report template

Copy this after every diff. No prose before the evidence.

## Success

```text
Objective: <one sentence>
Changed: <files + what>
Verified: `<command>` → <result>
Not verified / risks: <what you did not check>
Next: <one line, or "waiting for the next objective">
```

## Stop

```text
Stopped because: <two failures / diff too large / test edit needed / missing decision>
Evidence: `<command>` → <result>
Hypothesis: <one sentence>
Options: <A / B, with the trade-off>
Next: waiting for your decision.
```

## Clarification

```text
I need one decision before editing:
Question: <one question>
Default if you do not answer: <assumption>
Impact: <what changes if the default is wrong>
```
