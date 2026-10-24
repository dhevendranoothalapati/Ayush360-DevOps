# Remote VM / Cloud instance setup guide for Ayush360 DevOps

This repository is the deployment-only repo. Do not clone the frontend or backend repos onto the VM for runtime deployment. The VM should only contain the deployment files needed to pull the published GHCR images and run the container stack.

## 1) Connect to the VM

From your local machine:

```bash
ssh -i /Users/lazynoob/Downloads/ayushsandbox_key.pem azureuser@<PUBLIC_IP>
```

Then switch to root if needed:

```bash
sudo su
```

## 2) Clone the devOps repo only

From the VM:

```bash
git clone https://github.com/dhevendranoothalapati/Ayush360-DevOps.git
```

> This repo contains the deploy tooling, Compose file, env templates, and bootstrap script only.

## 3) Copy the example env file and create your real `.env`

From the devOps repo root:

```bash
cd ayush360-devOps
cp .env.sandbox.example .env
```

Then update `.env` with your real values:

```env
APP_VERSION=v1.0.0
GHCR_OWNER=dhevendranoothalapat
GITHUB_USER=dhevendranoothalapat
GHCR_TOKEN=<your-ghcr-read-token>
IDENTITY_IMAGE_TAG=v0.1.2
HMS_IMAGE_TAG=v0.1.2
MIGRATOR_IMAGE_TAG=v0.1.2
WEB_IMAGE_TAG=v0.1.3
WEB_PORT=8080
POSTGRES_DB=ayush360
POSTGRES_USER=ayush360_app
DB_PASSWORD=<strong-db-password>
DEMO_DATA_ENABLED=false
DEMO_DATA_PASSWORD=demo123
```

Important:
- do not commit `.env` to Git
- keep the file on the VM only
- use restricted permissions when possible

```bash
chmod 600 .env
```

## 4) Export the environment variables

Run this in every new shell session before running Docker Compose:

```bash
set -a
source .env
set +a
```

Verify the variables are exported:

```bash
env | grep -E '^(APP_VERSION|GHCR_OWNER|GITHUB_USER|GHCR_TOKEN|IDENTITY_IMAGE_TAG|HMS_IMAGE_TAG|MIGRATOR_IMAGE_TAG|WEB_IMAGE_TAG|WEB_PORT|POSTGRES_DB|POSTGRES_USER|DB_PASSWORD|DEMO_DATA_ENABLED|DEMO_DATA_PASSWORD)='
```

You should see all values from `.env` in the output.

## 5) Bootstrap the VM

From the devOps repo root:

```bash
cd /home/azureuser/ayush360-devOps/scripts
./bootstrap-vm.sh
```

This installs:
- Git
- Docker Engine
- Docker Compose plugin
- GHCR login via `docker login ghcr.io`

Validate login:

```bash
docker login ghcr.io
```

If the login succeeds, the host is ready to pull the Ayush360 images.

## 6) Start the Sandbox stack

The compose file lives here:

```text
/home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml
```

Start it with:

```bash
cd /home/azureuser/ayush360-devOps
docker compose -f docker-compose/docker-compose.sandbox.yml up -d
```

Or use inline env values:

```bash
cd /home/azureuser/ayush360-devOps
docker compose -f docker-compose/docker-compose.sandbox.yml --env-file .env up -d
```

## 7) Check container status and logs

List containers:

```bash
docker ps -a
```

Check logs for a service:

```bash
docker logs <container_id>
```

Examples:

```bash
docker logs ayush360-web
docker logs ayush360-identity
docker logs ayush360-hms
docker logs ayush360-db
```

Tail the latest logs:

```bash
docker logs --tail 200 <container_id>
```

## 8) Update image versions

You can update the versions in two ways.

### A. Update the `.env` file and reload compose

Edit `.env`:

```env
IDENTITY_IMAGE_TAG=v0.1.3
HMS_IMAGE_TAG=v0.1.3
MIGRATOR_IMAGE_TAG=v0.1.3
WEB_IMAGE_TAG=v0.1.4
```

Then:

```bash
set -a
source .env
set +a
docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml up -d --force-recreate
```

### B. Override directly at runtime

```bash
IDENTITY_IMAGE_TAG=v0.1.3 HMS_IMAGE_TAG=v0.1.3 MIGRATOR_IMAGE_TAG=v0.1.3 WEB_IMAGE_TAG=v0.1.4 \
  docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml up -d --force-recreate
```

You can also change the shared fallback:

```bash
APP_VERSION=v1.2.3 docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml up -d
```

The compose file resolves versions in this order:

1. service-specific env like `IDENTITY_IMAGE_TAG`
2. shared fallback `APP_VERSION`
3. `latest`

## 9) Common debugging tips

### A. Docker login fails

```bash
docker login ghcr.io -u <github-user> --password-stdin
```

Then paste the token.

Check:
- token has `read:packages`
- token is not expired
- the owner is lowercase, for example `lazynoob3`
- the image names match exactly

### B. Pull fails with unauthorized

```bash
docker pull ghcr.io/lazynoob3/ayush360-web:v0.1.3
```

If this fails, the most common causes are:
- GHCR token expired
- package is private and not readable
- wrong image tag or owner name
- package not published under that name

### D. Check environment values inside the VM shell

```bash
env | grep -E '^(APP_VERSION|GHCR_OWNER|GITHUB_USER|GHCR_TOKEN|IDENTITY_IMAGE_TAG|HMS_IMAGE_TAG|MIGRATOR_IMAGE_TAG|WEB_IMAGE_TAG|WEB_PORT|POSTGRES_DB|POSTGRES_USER|DB_PASSWORD|DEMO_DATA_ENABLED|DEMO_DATA_PASSWORD)='
```

### E. Restart a single service

```bash
docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml restart identity
docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml restart hms
docker compose -f /home/azureuser/ayush360-devOps/docker-compose/docker-compose.sandbox.yml restart web
```

## 10) Typical end-to-end flow

```bash
ssh -i /Users/lazynoob/Downloads/ayushsandbox_key.pem azureuser@<PUBLIC_IP>
sudo -i
cd /home/azureuser
git clone https://<github-user>:<github-token>@github.com/<github-user>/ayush360-devOps.git
cd /home/azureuser/ayush360-devOps
cp .env.sandbox.example .env
nano .env
set -a
source .env
set +a
env | grep -E '^(APP_VERSION|GHCR_OWNER|GITHUB_USER|GHCR_TOKEN|IDENTITY_IMAGE_TAG|HMS_IMAGE_TAG|MIGRATOR_IMAGE_TAG|WEB_IMAGE_TAG|WEB_PORT|POSTGRES_DB|POSTGRES_USER|DB_PASSWORD|DEMO_DATA_ENABLED|DEMO_DATA_PASSWORD)='
cd scripts
./bootstrap-vm.sh
docker login ghcr.io
cd /home/azureuser/ayush360-devOps
docker compose -f docker-compose/docker-compose.sandbox.yml --env-file .env up -d
docker ps -a
docker logs <container_id>
```

This is the recommended flow for a remote Linux VM using the separate deployment repo.

```bash
docker exec -it <container_id> bash
```

### F. Restart only one service

```bash
docker compose -f /home/azureuser/ayush360-BE/devops/docker-compose.prod.yml restart identity
docker compose -f /home/azureuser/ayush360-BE/devops/docker-compose.prod.yml restart hms
docker compose -f /home/azureuser/ayush360-BE/devops/docker-compose.prod.yml restart web
```

This is the standard deployment sequence for a remote Linux instance or cloud VM.
