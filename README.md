# payram-runtime-base

Runtime base image used by [`payram-core`](https://github.com/PayRam/payram-core) as the `FROM` for the final runtime stage.

The image contains the set of system packages every PayRam deployment needs — PostgreSQL, Redis, Supervisor, Node.js, and a few small utilities — all pinned to a known combination. Pre-building this image means the main `payram-core` Docker build doesn't have to reinstall these on every CI run, saving 1–2 minutes per build.

## What's inside

| Component | Version | Source |
|---|---|---|
| Debian | 13 (trixie), current point release | `debian:trixie-slim` + `apt-get upgrade` |
| Node.js | 26.12.1 (LTS from 28 Oct 2026) | official `node:26.12.1-trixie-slim` image |
| npm | 11.20.0 (comes with Node.js 26.12.1) | same image |
| PostgreSQL | 17 (latest minor) | `apt.postgresql.org` |
| Redis | latest release (modules off) | `packages.redis.io` |
| nginx | latest stable | `nginx.org` |
| Supervisor, gettext-base, wget | Debian 13 | apt |

Repository signing keys are pinned by checksum in the Dockerfile; a key
change fails the build until the new key is checked and its checksum
updated.

Nothing proprietary — this image is deliberately public so anyone can inspect, reproduce, or pull without authentication.

## Pulling the image

```bash
docker pull ghcr.io/payram/runtime-base:v2
```

Tag conventions:
- `vX.Y.Z` — exact version (e.g., `v2.0.0`).
- `vX` — floating tag for the latest in the major series (e.g., `v2` → `v2.0.0`, later `v2.1.0`).
- `latest` — most recently pushed tag.

`payram-core` should reference the **major** tag (`v2`) so it picks up patch/minor updates automatically. Only bump to `v3`, `v4`, etc., when you make a breaking change (e.g., PostgreSQL major-version upgrade).

## Using it from payram-core

In `payram-core/Dockerfile`:

```dockerfile
FROM ghcr.io/payram/runtime-base:v2 as base
```

That single line replaces the ~25 lines of apt-install work in the old base stage.

## Releasing a new version

1. Edit `Dockerfile` with the desired changes (e.g., bumping a package).
2. Update `CHANGELOG.md` with a one-line entry.
3. Commit to `main`.
4. Tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. GitHub Actions builds the image for `linux/amd64` and `linux/arm64`, then pushes it to GHCR under three tags: exact version, major, and `latest`.

### Versioning guidance

- **Patch (`v1.0.0` → `v1.0.1`)**: CVE fix, same software versions.
- **Minor (`v1.0.0` → `v1.1.0`)**: add or upgrade a minor component.
- **Major (`v1.0.0` → `v2.0.0`)**: breaking change — something `payram-core` must opt into (e.g., PostgreSQL 17 → 18).

## Manual build (for local testing)

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ghcr.io/payram/runtime-base:local-test \
  --load \
  .
```

## Package visibility

The image package lives at <https://github.com/orgs/PayRam/packages/container/package/runtime-base>.

On first push, GHCR packages default to private. Flip it to public once, under **Package settings → Danger Zone → Change visibility**.

## License

MIT — the image is a thin wrapper around upstream open-source components. See each underlying project for their own licenses.
