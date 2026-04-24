# Cloudflared Compose Integration Design

## Goal

Bring `cloudflared` into `docker compose` so the tunnel starts with the rest of the stack and no longer needs a separately managed host process.

## Constraints

- Cloudflare tunnel config and credentials must stay outside the repo.
- The runtime config directory must be supplied through `.env`.
- The existing `~/<user>/.cloudflared` layout should continue to work without changing the current `config.yml` structure.
- The change should preserve the current stack layout and avoid adding application-level dependencies on `cloudflared`.

## Selected Approach

Add a dedicated `cloudflared` service to `docker-compose.yml` using the official `cloudflare/cloudflared` image.

The service will:

- mount `${CLOUDFLARED_CONFIG_DIR}` read-only into `/etc/cloudflared`
- run `tunnel --config /etc/cloudflared/config.yml run`
- join the existing `en-practice` Docker network
- restart automatically with the rest of the stack

The environment file will define `CLOUDFLARED_CONFIG_DIR` so each machine can point to its own host-level Cloudflare config directory, for example `/home/<user>/.cloudflared`.

## Why This Approach

This keeps the operational model close to the current setup. The host still owns `config.yml` and tunnel credentials, but compose becomes the process supervisor. That removes the need to run `cloudflared` manually while keeping secrets and runtime-specific files out of the repository.

Alternative options were rejected:

- running `tunnel run <id>` without `config.yml` reduces reuse of ingress and tunnel settings already maintained in the host config
- moving config files into the repo conflicts with the requirement to keep tunnel config outside version control

## Compose Changes

`docker-compose.yml` will gain a new `cloudflared` service with:

- official image reference
- container restart policy
- read-only bind mount from `${CLOUDFLARED_CONFIG_DIR}` to `/etc/cloudflared`
- explicit command to use `/etc/cloudflared/config.yml`
- membership in the existing `en-practice` network

No application service needs to depend on `cloudflared`, because the tunnel is an ingress concern rather than an internal dependency for container startup.

## Environment Changes

The environment template and documentation will include:

- `CLOUDFLARED_CONFIG_DIR=/home/<user>/.cloudflared`

This keeps the path configurable across machines and avoids hardcoding a host-specific home directory in compose.

## Documentation Changes

`README.md` will be updated to:

- include `cloudflared` in the stack overview
- document the new `CLOUDFLARED_CONFIG_DIR` variable
- explain that `config.yml` and credentials remain in the host directory referenced by that variable
- update startup and troubleshooting sections so users manage the tunnel through `docker compose`

## Risks And Mitigations

### Host Path Portability

Risk: different hosts use different home paths.

Mitigation: expose the mount source through `CLOUDFLARED_CONFIG_DIR` in `.env` instead of hardcoding the path in compose.

### Missing Or Invalid Config Files

Risk: the container will fail if `${CLOUDFLARED_CONFIG_DIR}` does not contain a valid `config.yml` and required credentials.

Mitigation: document the expected directory contents in `README.md`.

### Compose Startup Expectations

Risk: users may assume the tunnel is healthy just because the container is running.

Mitigation: document log-based verification using `docker compose logs cloudflared`.

## Testing Plan

Because this is a compose and documentation change, validation is operational:

- run `docker compose config` to verify variable substitution and compose syntax
- confirm the `cloudflared` service renders correctly in the merged compose output
- optionally start the service on a host that has a valid Cloudflare config directory and inspect logs
