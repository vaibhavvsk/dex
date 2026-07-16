# Dex UBI9 Rebuild Guide

This document describes how to rebuild the [Dex](https://github.com/dexidp/dex) container image
using Red Hat Universal Base Image 9 (UBI9) as the base, replacing the upstream Alpine / distroless
base images. The resulting image is suitable for deployment in RHEL9-compatible environments
(OpenShift, ArgoCD, etc.).

---

## Repository & Branch

| | |
|---|---|
| **Repository** | `https://github.com/dexidp/dex` |
| **Branch** | `v2.43.0_ubi9` |
| **Upstream tag** | `v2.43.0` |
| **Dockerfile** | `Dockerfile` |

---

## Base Image Substitutions

| Stage | Upstream image | UBI9 replacement |
|---|---|---|
| `builder` | `golang:1.24.3-alpine3.20` | `registry.access.redhat.com/ubi9/ubi:9.8-1782841664` + Go `1.24.3` tarball |
| `stager` | `alpine:3.21.3` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` |
| `gomplate` | `alpine:3.21.3` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` |
| `ubi9-minimal` *(alias)* | `alpine:3.21.3 AS alpine` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` |
| `distroless` | `gcr.io/distroless/static-debian12:nonroot` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` |
| **runtime** (`$BASE_IMAGE`) | `alpine` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` |

> **Note:** The builder uses full `ubi9/ubi:9.8` (not minimal) to access `dnf` and the C toolchain
> (`gcc`, `glibc-static`, `libstdc++-static`) required for CGO. Go `1.24.3` is installed from the
> official tarball since no UBI9 image ships that version. The builder is a **build-time-only**
> stage — zero layers from it appear in the final image.

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Docker | 20.10+ | BuildKit enabled by default |
| Git | any | to clone / checkout the branch |
| Internet access | — | pulls base images and Go module dependencies |

> On **Windows**, run all `docker` commands inside **WSL2** or a Linux shell.  
> The commands below assume a Linux / WSL2 environment.

---

## Quick Build

```bash
# 1. Clone the repository (skip if already cloned)
git clone https://github.com/dexidp/dex.git
cd dex

# 2. Checkout the UBI9 branch
git checkout v2.43.0_ubi9

# 3. Build the image
make docker-build
```

This produces the image tagged `us.icr.io/dex/dex:v2.43.0_ubi9`.

---

## Make Variables

Override any variable on the command line:

| Variable | Default | Description |
|---|---|---|
| `DOCKER` | `docker` | Docker binary (`docker` or `podman`) |
| `TARGETARCH` | `amd64` | Target CPU architecture |
| `TARGETOS` | `linux` | Target OS |
| `REGISTRY_NAMESPACE` | `dex` | Registry namespace / org |
| `REGISTRY_IMAGE` | `dex` | Image name |
| `REGISTRY_IMAGE_TAG_SHORT` | `v2.43.0_ubi9` | Image tag |

```bash
# Custom registry namespace and tag
make docker-build REGISTRY_NAMESPACE=myorg REGISTRY_IMAGE_TAG_SHORT=v2.43.0-ubi9

# Use podman instead of docker
make docker-build DOCKER=podman

# Custom registry, namespace, image name, and tag
make docker-build \
  REGISTRY_NAMESPACE=myorg \
  REGISTRY_IMAGE=dex \
  REGISTRY_IMAGE_TAG_SHORT=v2.43.0-ubi9
```

The full image reference produced is:
```
us.icr.io/<REGISTRY_NAMESPACE>/<REGISTRY_IMAGE>:<REGISTRY_IMAGE_TAG_SHORT>
```

---

## Build Directly with Docker

```bash
# Default (equivalent to make docker-build)
docker buildx build \
  -f Dockerfile \
  --build-arg TARGETARCH=amd64 \
  --build-arg TARGETOS=linux \
  -t us.icr.io/dex/dex:v2.43.0_ubi9 \
  .

# With custom Go proxy
docker buildx build \
  -f Dockerfile \
  --build-arg TARGETARCH=amd64 \
  --build-arg TARGETOS=linux \
  --build-arg GOPROXY=https://proxy.golang.org,direct \
  -t us.icr.io/dex/dex:v2.43.0_ubi9 \
  .

# With full UBI9 as runtime base instead of UBI9-minimal
docker buildx build \
  -f Dockerfile \
  --build-arg TARGETARCH=amd64 \
  --build-arg TARGETOS=linux \
  --build-arg BASE_IMAGE=registry.access.redhat.com/ubi9/ubi:9.8-1782841664 \
  -t us.icr.io/dex/dex:v2.43.0_ubi9-full \
  .
```

---

## Build Arguments Reference

| Argument | Default | Description |
|---|---|---|
| `BASE_IMAGE` | `registry.access.redhat.com/ubi9/ubi-minimal:9.8-1782797275` | Runtime base image |
| `TARGETARCH` | `amd64` | Target CPU architecture |
| `TARGETOS` | `linux` | Target OS |
| `GOPROXY` | *(Go default)* | Go module proxy URL |

---

## Verify the Image

```bash
# Check Dex version and Go runtime
docker run --rm us.icr.io/dex/dex:v2.43.0_ubi9 dex version

# Confirm the base OS is RHEL9
docker run --rm --entrypoint cat us.icr.io/dex/dex:v2.43.0_ubi9 /etc/redhat-release

# Inspect image size and metadata
docker image inspect us.icr.io/dex/dex:v2.43.0_ubi9 \
  --format 'Size: {{.Size}} bytes | Created: {{.Created}}'
```

Expected output:
```
Dex Version: v2.43.0
Go Version: go1.24.3
Go OS/ARCH: linux amd64
---
Red Hat Enterprise Linux release 9.8 (Plow)
```

---

## Run the Image

```bash
docker run --rm \
  -p 5556:5556 \
  -e DEX_ISSUER=http://localhost:5556/dex \
  us.icr.io/dex/dex:v2.43.0_ubi9 \
  dex serve /etc/dex/config.docker.yaml
```

---

## Tooling Versions (pinned)

These versions are identical to the upstream `Dockerfile` and `Makefile` at tag `v2.43.0`:

| Tool | Version |
|---|---|
| Go | `1.24.3` |
| gomplate | `v4.3.0` |
| golangci-lint | `1.64.5` |
| gotestsum | `1.12.0` |
| protoc | `29.3` |
| protoc-gen-go | `1.36.5` |
| protoc-gen-go-grpc | `1.5.1` |

---

## Notes

- **Architecture:** The image targets `linux/amd64` only (`GOARCH=amd64 GOOS=linux` are set
  explicitly in the builder stage) to avoid cross-compilation overhead.
- **CGO:** `CGO_ENABLED=1` is required by the `go-sqlite3` dependency (uses C bindings).
  Static linking (`-extldflags "-static"`) requires `glibc-static`, `glibc-devel`, and
  `libstdc++-static` — all installed in the builder via `dnf`. Linker warnings about
  `dlopen`/`getaddrinfo` at link time are expected and match the upstream build behaviour.
- **CA certificates:** Copied from `/etc/pki/tls/certs/ca-bundle.crt` in the UBI9 builder
  (the RHEL CA bundle path) to `/etc/ssl/certs/ca-certificates.crt` in the runtime image,
  ensuring all OIDC connectors (GitHub, Google, etc.) work out of the box.
- **VERSION:** The version string is resolved automatically inside the builder via `git describe`
  (git is installed in the builder stage). To override, pass `--build-arg VERSION=v2.43.0`
  directly to `docker buildx build`.
- **Non-root runtime:** The container runs as UID/GID `1001:1001` matching the upstream image.
  This branch does not have a `user-setup` stage — the numeric UID is set directly via `USER 1001:1001`.
- **gomplate:** Downloaded directly from GitHub Releases inside a dedicated build stage;
  `curl-minimal` (pre-installed in UBI9-minimal) is used to avoid a package conflict with `curl`.
- **distroless alias:** The `distroless` named stage is retained for Dependabot parity with the
  upstream Dockerfile; it resolves to `ubi9-minimal` and is not used in the runtime layer chain.
