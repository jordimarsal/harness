# SonarQube Review Protocol (sonarqube module)

> Installed by the harness `sonarqube` module. The reviewer runs
> `bash harness/tools/sonar-review.sh` before the verdict. A reachable server
> turns the Quality Gate into a hard review gate; an unreachable one is a
> recorded skip — never a fake pass, never a blocker.

## What it does

The tool checks, in order:

1. **Config** — `SONAR_HOST_URL` + `SONAR_TOKEN` from the environment, else
   `harness/sonar.env` (gitignored; see `harness/sonar.env.example`). No
   token anywhere → the check is skipped.
2. **Server** — `GET /api/system/status` must answer `UP`. When the URL is a
   local default (`localhost`/`127.0.0.1`) and unreachable, the tool
   auto-discovers a `sonarqube` Docker container (name override:
   `SONAR_CONTAINER`) and uses its bridge IP — reachable from the host and,
   placing the scanner on the same network, from the scanner container too.
3. **Analysis** — mode `auto` (default): full scan when a `sonar-scanner`
   binary or Docker (scanner image) exists; otherwise `api` mode reads the
   last stored analysis. Project key resolves from
   `sonar-project.properties`, then the git remote (`owner:repo`), then the
   directory name.

## Exit codes and what the reviewer does with them

| Exit | Meaning | Reviewer action |
|---|---|---|
| `0` | Quality gate **passed** | Record: `SonarQube: PASS (gate OK)`. Evidence for G3-style maintainability, not for requirement coverage |
| `1` | Quality gate **failed** | **Reject the approval** (`CHANGES_REQUESTED`), citing the failed conditions. Never approve over exit 1 |
| `2` | SonarQube not available (no token, server down, no scanner) | Record: `SonarQube: skipped (<reason>)`. The review proceeds on its own evidence; a skip is not a pass |
| `3` | Analysis error (scan or Compute Engine failed) | Record: `SonarQube: error (<reason>)` and proceed like a skip — but name it an error, not a skip, so the failure stays visible |

`--report-only` turns exit 1 into exit 0 (the report still says FAILED) —
use it deliberately, e.g. while the server is being migrated, and record the
waiver in the review file.

## Configuration

`harness/sonar.env` (gitignored — never commit tokens):

```bash
SONAR_HOST_URL=http://localhost:9000
SONAR_TOKEN=<user token>
# optional: SONAR_ORG=<cloud org>, SONAR_SCANNER_BIN=/path/to/sonar-scanner
```

The environment wins over the file, so CI can inject its own credentials.
The project key and default exclusions live in `sonar-project.properties`
(created on install when missing); anything that file defines overrides the
tool's automatic values.

## Report format (in the review file)

```markdown
## SonarQube
- Command: bash harness/tools/sonar-review.sh
- Result: PASS | FAILED | skipped (<reason>) | error (<reason>)
- Gate conditions failed (if any): <metric list>
```

## First-time setup

1. Reach a SonarQube server (local Docker, homelab, or company instance) —
   the standalone `sonarqube` skill walks through server install, token
   provisioning and project wiring.
2. Create a **user** token (My Account → Security) and put it in
   `harness/sonar.env`.
3. Run `bash harness/tools/sonar-review.sh` once by hand; exit `0` means the
   loop is closed. The first analysis of a new project has no baseline, so
   every issue counts as new code — expect the gate to reflect that until a
   reference branch or version exists.
