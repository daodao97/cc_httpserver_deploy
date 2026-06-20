# cc-httpserver Deploy

This repository hosts public deployment artifacts for `cc-httpserver`.

## Pull from GHCR

```bash
docker pull ghcr.io/daodao97/cc_httpserver_deploy/backend:latest
```

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

Release assets include a `cc-httpserver-backend-<version>.tar.gz` Docker image
archive. Load it with:

```bash
gzip -dc cc-httpserver-backend-v0.0.1.tar.gz | docker load
BACKEND_IMAGE=ghcr.io/daodao97/cc_httpserver_deploy/backend:v0.0.1 docker compose up -d
```
