# Ayush360 Production Docker Compose Guide

This guide explains how to run the production-style Docker Compose stack on a VM or cloud instance, and which environment variables and secrets must be present on the host.

## 1. What the production stack runs

The file `devops/docker-compose.prod.yml` starts:

- `db` — PostgreSQL 18
- `migrate` — one-off migration job
- `identity` — auth API
- `hms` — core hospital management API
- `web` — public frontend container

The `web` container is the public entry point. The API containers stay internal to the Docker network.

## 2. Required host setup

On the target VM, install:

- Docker Engine
- Docker Compose plugin
- a GitHub Container Registry login if the repository is private
- enough disk space for PostgreSQL data and container storage
- a stable hostname or public IP for the VM

If the instance is pulling images from GHCR and the package is private, run:

```bash
docker login ghcr.io -u <github-user> -p <ghcr-token>
```

The token should allow `read:packages` access.

## 3. Required environment variables

Create a file named `.env` next to the compose file, or export these values before running Docker Compose.

Example:

```env
APP_VERSION=v1.2.3
GHCR_OWNER=lazynoob3
GITHUB_USER=lazynoob3
GHCR_TOKEN=replace-with-ghcr-read-token
IDENTITY_IMAGE_TAG=v1.2.3
HMS_IMAGE_TAG=v1.2.4
MIGRATOR_IMAGE_TAG=v1.2.5
WEB_IMAGE_TAG=v1.2.6
WEB_PORT=8080
POSTGRES_DB=ayush360
POSTGRES_USER=ayush360_app
DB_PASSWORD=change-me-strong-password
DEMO_DATA_ENABLED=false
DEMO_DATA_PASSWORD=demo123
```

### Meaning of each variable

| Variable | Required | Purpose |
|---|---|---|
| `APP_VERSION` | Yes | Shared fallback release tag used when a service-specific tag is not set |
| `GHCR_OWNER` | Yes | GitHub username or org name that owns the GHCR package |
| `GITHUB_USER` | Yes | GitHub username used for GHCR login |
| `GHCR_TOKEN` | Yes | GHCR read token or personal access token used for `docker login` |
| `IDENTITY_IMAGE_TAG` | Optional | Image tag for `ayush360-identity` |
| `HMS_IMAGE_TAG` | Optional | Image tag for `ayush360-hms` |
| `MIGRATOR_IMAGE_TAG` | Optional | Image tag for `ayush360-migrator` |
| `WEB_IMAGE_TAG` | Optional | Image tag for `ayush360-web` |
| `WEB_PORT` | Yes | Host port exposed for the frontend, usually `8080` |
| `POSTGRES_DB` | Yes | Database name |
| `POSTGRES_USER` | Yes | PostgreSQL user |
| `DB_PASSWORD` | Yes | Strong password for PostgreSQL |
| `DEMO_DATA_ENABLED` | Optional | Enables demo seed data for test environments only |
| `DEMO_DATA_PASSWORD` | Optional | Password for demo users |

## 4. Protected runtime secrets

These are not safe to hardcode in Git or in a plain `.env` file if the instance is shared. Store them in a secure secret manager or in a host-only environment file with restricted permissions.

### Required by the app containers

| Secret / env var | Used by | Notes |
|---|---|---|
| `ConnectionStrings__Default` | `identity`, `hms`, `migrator` | Built from `DB_PASSWORD` by the compose file |
| `Jwt__SigningKeyPem` | `identity` | Must contain the RSA private key used to sign tokens |
| `Jwt__JwksUrl` | `hms` | Usually `http://identity:8080/.well-known/jwks.json` |
| `Aadhaar__EncryptionKey` | `hms` | Required for encrypted Aadhaar values |
| `Aadhaar__HashKey` | `hms` | Different from the encryption key |
| `ASPNETCORE_ENVIRONMENT` | all .NET containers | Use `Production` on real servers |

## 5. Compose commands

From the backend repo root:

```bash
cp devops/.env.production.example .env
# edit .env with the real values
set -a
source .env
set +a

APP_VERSION=${APP_VERSION} GHCR_OWNER=${GHCR_OWNER} \
  GITHUB_USER=${GITHUB_USER} GHCR_TOKEN=${GHCR_TOKEN} \
  docker compose -f devops/docker-compose.prod.yml up -d
```

If you want to export the file into the current shell without sourcing it manually:

```bash
set -a && source ./devops/.env.production.example && set +a
```

Or, for a clean VM setup, use the bootstrap script first:

```bash
export GITHUB_USER=your-github-user
export GHCR_TOKEN=your-ghcr-read-token
./devops/bootstrap-vm.sh
```

To check status:

```bash
docker compose -f devops/docker-compose.prod.yml --env-file .env ps
docker compose -f devops/docker-compose.prod.yml --env-file .env logs -f
```

To stop and keep data:

```bash
docker compose -f devops/docker-compose.prod.yml --env-file .env down
```

To wipe database and volumes:

```bash
docker compose -f devops/docker-compose.prod.yml --env-file .env down -v
```

## 6. Instance checklist

Before release, verify the following on the VM:

- host can pull GHCR images
- `.env` file is present and permissions are locked down
- PostgreSQL password is strong and unique
- `identity` has a valid JWT signing key
- `hms` has Aadhaar encryption and hash keys
- `web` port is open and fronted by a reverse proxy or public load balancer if needed
- `DB_PASSWORD` is not printed in logs or shell history

## 7. Production safety notes

- Never run `DEMO_DATA_ENABLED=true` in prod
- Do not commit `.env` files to Git
- Keep `APP_VERSION` pinned to the exact release tag you want
- Use a dedicated VM user with minimal permissions
- Back up the database and keys before a release

## 8. Recommended deployment order

1. pull the release images
2. run `migrate` and wait for success
3. start `identity`
4. start `hms`
5. start `web`

This ordering ensures the schema is ready before API traffic enters the system.

## 9. Example one-line cloud deployment

```bash
APP_VERSION=v1.2.3 GHCR_OWNER=lazynoob3 docker compose -f devops/docker-compose.prod.yml --env-file .env up -d
```

That is the simplest pattern to use on a VM, EC2 instance, or any single-server cloud host.
