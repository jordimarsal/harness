# Installing SonarQube locally

Server, scanner, and project wiring for a self-hosted Community Build. Every
step is reversible (`docker compose down -v` removes everything).

## 1. Server (Docker Compose, no host ports)

`docker-compose.yml`:

```yaml
services:
  sonarqube:
    image: sonarqube:community
    depends_on: [sonarqube-db]
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
      SONAR_JDBC_USERNAME: ${SONAR_DB_USER}
      SONAR_JDBC_PASSWORD: ${SONAR_DB_PASSWORD}
      SONAR_TELEMETRY_ENABLE: "false"
    volumes:
      - sonarqube-data:/opt/sonarqube/data
      - sonarqube-extensions:/opt/sonarqube/extensions
      - sonarqube-logs:/opt/sonarqube/logs
  sonarqube-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${SONAR_DB_USER}
      POSTGRES_PASSWORD: ${SONAR_DB_PASSWORD}
      POSTGRES_DB: sonarqube
    volumes:
      - sonarqube-db:/var/lib/postgresql/data

volumes:
  sonarqube-data:
  sonarqube-extensions:
  sonarqube-logs:
  sonarqube-db:
```

```bash
docker compose up -d          # first boot takes ~2 min; watch: docker logs -f sonarqube
```

Notes:

- No `ports:` — the server stays on the compose network. Clients reach it via
  the container's bridge IP (`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' sonarqube`)
  or a reverse proxy if you want a browser URL. To publish instead, add
  `ports: ["127.0.0.1:9000:9000"]` — bind to loopback, never `0.0.0.0`.
- Search engines: the embedded Elasticsearch refuses a low `vm.max_map_count`
  (raise it: `sudo sysctl -w vm.max_map_count=262144`, persist in
  `/etc/sysctl.conf`). Memory: give the VM ≥ 4 GB or set
  `SONAR_CE_JAVAOPTS: -Xmx1g` / `SONAR_WEB_JAVAOPTS: -Xmx1g`.

## 2. Token provisioning (once)

The default `admin` account forces a password change; do the setup in the
browser once, then automate the rest:

```bash
# 1. change the default password in the UI (or via /api/users/change_password)
# 2. create a service user + token:
curl -u admin:<new-password> -X POST "$HOST/api/users/create?login=agent&name=Agent&local=true"   # admin-only
curl -u admin:<new-password> -X POST "$HOST/api/users/revocation_token?login=agent" -d "name=agent-token"   # returns {token}
# 3. grant it what it needs: "Execute Analysis" on the project(s) or globally:
curl -u admin:<new-password> -X POST "$HOST/api/permissions/apply_template?..."   # or grant_permission
```

Store the token gitignored (`harness/sonar.env` in harness projects):

```bash
SONAR_HOST_URL=http://<container-ip>:9000
SONAR_TOKEN=<token>
```

## 3. Scanner

One of:

```bash
# native binary (recommended for host-side runs)
brew install sonar-scanner            # macOS
sdk install sonar-scanner             # SDKMAN / Linux
# docker (zero install; the harness tool falls back to this automatically)
docker pull sonarsource/sonar-scanner-cli
```

## 4. Project wiring

Minimal `sonar-project.properties` at the repo root:

```properties
sonar.projectKey=owner:repo        # or leave to the tool's git-remote derivation
sonar.sourceEncoding=UTF-8
sonar.exclusions=**/node_modules/**,**/dist/**,**/build/**,**/target/**,**/.venv/**,**/__pycache__/**
sonar.test.inclusions=**/*.spec.ts,**/*.test.ts,**/*_test.py,**/test_*.py
```

Language extras:

| Language | Requirement |
|---|---|
| Java/Kotlin | compiled bytecode: `sonar.java.binaries=target/classes` (or `build/classes/java/main`) — or run analysis through the Maven/Gradle sonar plugin instead of the raw scanner |
| JS/TS | nothing extra; tests detected via `sonar.test.inclusions` |
| Python | nothing extra; coverage via `sonar.python.coverage_reportPaths=coverage.xml` (pytest `--cov-report=xml`) |
| Go/Rust/PHP | raw scanner works; Go also benefits from compiled packages for richer rules |

First run:

```bash
sonar-scanner -Dsonar.token="$SONAR_TOKEN"     # or the harness tool: bash harness/tools/sonar-review.sh
```

Then open `http://<host>:9000/dashboard?id=<key>` and check the gate.

## 5. Quality gates

The built-in **Sonar way** gate (Community Build default) fails new code on:
any new bug/vulnerability, security-rating below A, unreviewed security
hotspots, duplication > 3%, maintainability rating below A. Coverage-on-new
code requires a coverage report — without one the condition is not measurable
and the gate can still pass.

Custom gates need admin APIs (`/api/qualitygates/*`) — do that as a human
setup task, not from a feature session.
