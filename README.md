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
HTTP_PORT=8080
MYSQL_DATA_DIR=./data/mysql
```

`CC_LICENSE` must be a complete license token issued by the project owner. It
must start with `cclic_v1.` and has three dot-separated parts:

```text
cclic_v1.<payload>.<signature>
```

Do not use placeholder values such as `test`; the container will exit with:

```text
cc-httpserver worker license check failed: invalid license token format
```

Start:

```bash
docker compose up -d
```

The public endpoint is the nginx `lb` service:

```text
http://localhost:${HTTP_PORT:-8080}
```

MySQL data is stored on the host at `MYSQL_DATA_DIR` and defaults to
`./data/mysql`.

After changing `.env`, recreate the app containers:

```bash
docker compose up -d --force-recreate
```

## Issue a License

License issuing is done from the private source repository by the project owner.
The private key must match the public key baked into the Docker image during the
GitHub Actions build.

Generate a license:

```bash
LICENSE_PRIVATE_KEY_FILE=./license-private.pem \
  bun run scripts/issueLicense.ts --customer self --days 365 --out self.license
```

Then copy the full one-line token from `self.license` into `.env`:

```env
CC_LICENSE=cclic_v1.<payload>.<signature>
```

Common license errors:

```text
invalid license token format
```

The value is not a license token, is empty, or was copied with extra text.

```text
license signature is invalid
```

The token was signed by a different private key than the public key built into
the image.

```text
license has expired
```

The `exp` timestamp in the license is in the past. Issue a new license.

## Offline Image Download

Release assets include per-platform Docker image archives. Load the one matching
your machine:

```bash
gzip -dc cc-httpserver-backend-v0.0.1-linux-arm64.tar.gz | docker load
BACKEND_IMAGE=ghcr.io/daodao97/cc_httpserver_deploy/backend:v0.0.1 docker compose up -d
```
