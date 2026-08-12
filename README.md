# java_oci_manager

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/mrshyi/java_oci_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/mrshyi/java_oci_manager/actions/workflows/ci.yml)
[![Publish image](https://github.com/mrshyi/java_oci_manager/actions/workflows/publish.yml/badge.svg)](https://github.com/mrshyi/java_oci_manager/actions/workflows/publish.yml)

This repository builds a self-owned, multi-architecture image for the native
R-Bot client distributed by `semicons/java_oci_manage`.

The application version and official SHA-256 checksums are pinned at build
time. The application binary runs in the foreground as the container's managed
process; the upstream background-service script is intentionally not used.

## Quick deployment

Requires Docker Engine with Compose v2. Run:

```bash
curl -fsSL https://raw.githubusercontent.com/mrshyi/java_oci_manager/main/scripts/install.sh | sh
```

When deployment finishes, open:

```text
https://SERVER_IP:9527
```

The default configuration listens on all network interfaces (`0.0.0.0`) for
easy testing. Allow TCP port `9527` in the server firewall or cloud security
group if needed. A self-signed certificate warning on first access is expected.

## Security model

- Runs as unprivileged UID/GID `10001:10001`.
- Drops all Linux capabilities and enables `no-new-privileges`.
- Uses a read-only root filesystem.
- Stores mutable application state in a named volume.
- Mounts API private keys separately and read-only.
- Binds to all interfaces by default for quick testing; restrict the firewall
  and switch to localhost binding after testing whenever possible.
- Verifies the downloaded release archive with its official SHA-256 digest.

## Publish this repository and image

This repository follows the operating model of
`vay1314/java_oci_manage_docker`, while pinning upstream checksums and running
the native client as the container's foreground process.

Create an empty GitHub repository named `java_oci_manager`, then push this
working tree:

```bash
git remote add origin https://github.com/mrshyi/java_oci_manager.git
git push -u origin main
```

The `Publish image` workflow runs daily at `01:17 UTC`, can be started
manually, and supports an `upstream-release` repository-dispatch event. It:

1. Resolves the selected `semicons/java_oci_manage` GitHub Release.
2. Reads the official AMD64-compatible and ARM64 SHA-256 digests.
3. Builds `linux/amd64` and `linux/arm64` images.
4. Publishes `<version>` and `latest` to GitHub Container Registry.
5. Attaches build provenance and an SBOM.

GHCR requires no repository secrets. After the first successful workflow, make
the package public in **GitHub profile -> Packages -> Package settings ->
Change visibility** if anonymous pulls are desired.

```bash
docker pull ghcr.io/mrshyi/java_oci_manager:latest
```

To publish to Docker Hub too, create the Docker Hub repository and configure:

- GitHub variable `DOCKERHUB_USERNAME`: your Docker Hub username.
- GitHub secret `DOCKERHUB_TOKEN`: a Docker Hub access token with read/write
  access to that repository. Do not use your account password.

If these settings are absent, Docker Hub is skipped and GHCR continues
normally. To deploy the published image, set this in `.env`:

```dotenv
RBOT_IMAGE=ghcr.io/mrshyi/java_oci_manager:10.5.0
```

Then start without rebuilding:

```bash
docker compose pull
docker compose up -d --no-build
```

Workflow actions are pinned to exact commit SHAs. Dependabot checks weekly for
newer Docker and GitHub Actions dependencies.

Scheduled and empty-version manual runs update both the immutable version tag
and `latest`. A manual run for a historical version publishes only its immutable
version tag, so it cannot roll `latest` backward. When Docker Hub publishing is
enabled later, the workflow also backfills a version that already exists in
GHCR.

## Build locally and start

Requirements: Docker Engine with the Compose v2 plugin.

```bash
cd /path/to/java_oci_manager
cp .env.example .env
mkdir -p config secrets
docker compose build --pull
docker compose up -d
docker compose ps
docker compose logs -f rbot
```

Open `https://127.0.0.1:9527` on the Docker host. The upstream application uses
a self-signed certificate initially, so a browser certificate warning is
expected.

On first start, the upstream `client_config` template is copied into the
`java-oci-manage-data` volume. The application can then initialize credentials,
and configuration can be managed from its Web UI.

To seed an existing configuration, place it at
`config/client_config` **before the first start**. It must be readable by UID
10001. On Linux:

```bash
chown 10001:10001 config/client_config
chmod 600 config/client_config
```

The file is imported only when the persistent volume has no `client_config`, so
recreating or upgrading the container never overwrites live configuration.

## OCI and other private keys

Store keys under `secrets/`, never in the image or configuration directory:

```bash
chown -R 10001:10001 secrets
chmod 700 secrets
chmod 600 secrets/*.pem
```

Use the **container path** in `client_config`:

```ini
key_file=/run/rbot-secrets/oci_api.pem
```

Do not commit `.env`, `client_config`, private keys, exported credentials, or
the persistent volume contents.

## Network exposure

The default Compose setting publishes port `9527` on every host interface:

```text
0.0.0.0:9527 -> container:9527
```

This allows direct access through `https://SERVER_IP:9527` after the host
firewall or cloud security group permits TCP port `9527`. It is intended for
quick testing. Because this application can control cloud resources, restrict
allowed source addresses and do not leave it openly reachable from the
Internet.

To bind only to the Docker host, set this in `.env` and recreate the container:

```dotenv
RBOT_BIND_ADDRESS=127.0.0.1
```

```bash
docker compose up -d --no-build --force-recreate
```

## Upgrade and rollback

Do not use the upstream in-container script upgrade command. Treat images as
immutable:

1. Find the desired upstream release assets and their SHA-256 digests.
2. Update `RBOT_VERSION`, `RBOT_SHA256_AMD64`, and `RBOT_SHA256_ARM64` together
   in `.env`.
3. Give `RBOT_IMAGE` a matching immutable tag.
4. Rebuild and recreate the container.

```bash
docker compose build --pull --no-cache
docker compose up -d
```

The named data volume remains unchanged. To roll back, restore the previous
version, checksums, and image tag, then run `docker compose up -d` again.

Back up the data volume before an upgrade:

```bash
docker run --rm \
  -v java-oci-manage-data:/source:ro \
  -v "$PWD/backups:/backup" \
  alpine:3.22 \
  tar -czf /backup/rbot-data.tgz -C /source .
```

## Multi-architecture publishing

After logging in to your registry:

```bash
docker buildx create --use --name rbot-builder
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg RBOT_VERSION=10.5.0 \
  --build-arg RBOT_SHA256_AMD64=7b7a99cdf25f73c5d07335a37da326014e52910b55e4501e997e9cade4d41bf2 \
  --build-arg RBOT_SHA256_ARM64=098408934188bfff680563ac9ec41aab61f613c7c00b32829c45e9ec8780e9fc \
  --tag REGISTRY/OWNER/java-oci-manage:10.5.0 \
  --push .
```

Only publish the container files you created. Review the upstream project's
terms before redistributing its binary in a public registry.

## Operations

```bash
# Status and health
docker compose ps

# Logs
docker compose logs --tail=200 -f rbot

# Stop without deleting persistent state
docker compose down

# Inspect the persistent configuration
docker compose exec rbot sh -c 'ls -la /var/lib/rbot'
```

Deleting the named volume permanently removes the application state. Do not run
`docker compose down -v` unless that is explicitly intended and a backup exists.
