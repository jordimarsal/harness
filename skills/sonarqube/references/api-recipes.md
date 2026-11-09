# API recipes

All calls: `curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/..."` (the token
is the username, the password is empty). `jq` or `python3 -m json.tool` for
parsing. Hosts that publish no ports: use the container bridge IP
(`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' sonarqube`).

## Server and project

```bash
# server health (no auth needed)
curl -s "$HOST/api/system/status"                     # {"status":"UP"}

# search projects ( paginated: ps/p )
curl -s -u "$TOKEN:" "$HOST/api/projects/search?q=harness" | jq -r '.components[].key'

# project exists? (404 body = {"errors":[...]})
curl -s -u "$TOKEN:" "$HOST/api/components/show?component=<key>"
```

## Quality gate

```bash
curl -s -u "$TOKEN:" "$HOST/api/qualitygates/project_status?projectKey=<key>"
```

Green: `{"projectStatus":{"status":"ERROR"|"OK", "conditions":[…]}}` — read
`status`, then failed conditions:

```bash
curl -s -u "$TOKEN:" "$HOST/api/qualitygates/project_status?projectKey=<key>" \
  | jq -r '.projectStatus.conditions[] | select(.status=="ERROR") |
           "\(.metricKey) \(.comparator) \(.errorThreshold) (actual: \(.actualValue))"'
```

Status vocabulary varies by version: `OK`/`ERROR` (recent) or
`PASSED`/`FAILED` (old) — accept both.

## Issues

```bash
# open issues, worst first (severities: INFO,LOW,MEDIUM,HIGH,BLOCKER)
curl -s -u "$TOKEN:" "$HOST/api/issues/search?projectKeys=<key>&issueStatuses=OPEN&severities=HIGH,BLOCKER&ps=50" \
  | jq -r '.issues[] | "\(.severity)\t\(.rule):\(.line)\t\(.message)"'

# new-code issues only
curl -s -u "$TOKEN:" "$HOST/api/issues/search?projectKeys=<key>&issueStatuses=OPEN&inNewCode=true"

# issues on the files the feature touched
files=$(git diff --name-only main...HEAD | tr '\n' ',')
curl -s -u "$TOKEN:" "$HOST/api/issues/search?projectKeys=<key>&issueStatuses=OPEN&componentKeys=<key>:$files"
```

Rules for triage:

- Read the rule before fixing: `curl -s -u "$TOKEN:" "$HOST/api/rules/show?key=<rule>"`
  — the `htmlDesc` names the compliant and non-compliant patterns.
- Fix at the source; every `// NOSONAR` needs a written justification.
- Marking issues `ACCEPTED`/`FALSE-POSITIVE` is a mutation — human call, not
  the agent's.

## Security hotspots

```bash
curl -s -u "$TOKEN:" "$HOST/api/hotspots/search?projectKey=<key>&status=TO_REVIEW" \
  | jq -r '.hotspots[] | "\(.key)\t\(.ruleKey)\t\(.message)"'

# details + how to fix
curl -s -u "$TOKEN:" "$HOST/api/hotspots/show?hotspot=<key>" | jq .rule
```

Unreviewed hotspots fail the Sonar way gate — triage them (mark SAFE with a
comment only when the human confirms the rationale).

## Measures

```bash
curl -s -u "$TOKEN:" "$HOST/api/measures/component?component=<key>&metricKeys=ncloc,complexity,coverage,duplicated_lines_density,sqale_rating" \
  | jq -r '.component.measures[] | "\(.metric): \(.value)"'
```

## Compute Engine (why the gate lags the scan)

The scanner upload ends before the verdict exists. Track the task:

```bash
TASK=$(sonar-scanner ... | grep -oE 'api/ce/task\?id=[0-9a-f-]+' | tail -1 | cut -d= -f2)
curl -s -u "$TOKEN:" "$HOST/api/ce/task?id=$TASK" | jq -r '.task.status'   # SUCCESS | FAILED | CANCELED | IN_PROGRESS
```

Poll the gate only after `SUCCESS` — otherwise you read the previous
analysis' verdict.
