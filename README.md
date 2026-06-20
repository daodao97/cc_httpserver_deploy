# cc-httpserver Deploy

This repository hosts public deployment artifacts for `cc-httpserver`.

## Pull from GHCR

```bash
docker pull ghcr.io/daodao97/cc_httpserver_deploy/backend:latest
```

The image is published for both `linux/amd64` and `linux/arm64`, so the same tag
works on x86 servers and Apple Silicon / ARM servers.

For a tagged release:

```bash
docker pull ghcr.io/daodao97/cc_httpserver_deploy/backend:v0.0.1
```

## Run

Create a `.env` file:

```env
SERVER_MASTER_KEY=change-this
ADMIN_PASSWORD=change-this
CC_LICENSE=cclic_v1...
BACKEND_IMAGE=ghcr.io/daodao97/cc_httpserver_deploy/backend:latest
```

Start:

```bash
docker compose up -d
```

## Offline Image Download

Release assets include per-platform Docker image archives. Load the one matching
your machine:

```bash
gzip -dc cc-httpserver-backend-v0.0.1-linux-arm64.tar.gz | docker load
BACKEND_IMAGE=ghcr.io/daodao97/cc_httpserver_deploy/backend:v0.0.1 docker compose up -d
```
