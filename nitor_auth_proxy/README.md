# Nitor Auth Proxy Add-on

Home Assistant add-on wrapping the Nitor Java backend proxy for SSO and header-based identity forwarding.

## Features

- Entra ID authentication and group gating.
- HA-oriented forwarded headers (`x-ha-user`, `x-ha-groups`, `x-ha-id`).
- Runtime-only secret injection for Entra client secret.
- Persistent cookie secret generated on first boot (`/data/auth-cookie-secret` by default).
- Optional TLS termination from Home Assistant `/ssl` (`certfile`, `keyfile`).
- HA-compatible CSP override is set in template to allow frontend inline boot scripts.
- `virtualHost` is set to `false` in the generated proxy config (single-host app flow).
- Proxy websocket limits are set to 8 MiB in generated service config to support larger Home Assistant frames.

## Required add-on options

- `public_uri`
- `session_server_name`
- `allowed_groups_regex`
- `entra_client_id`
- `entra_client_secret`
- `entra_configuration_uri`
- `aws_region` (required by AWS SDK initialization; default `eu-west-1`)

## TLS configuration

When `ssl: true`, the add-on expects:

- `/ssl/<certfile>`
- `/ssl/<keyfile>`

These map to proxy config:

- `tls.serverCert`
- `tls.serverKey`

## Security notes

- The add-on process runs as root to ensure read access to `/data/options.json` in Home Assistant Supervisor runtime.
- Keep Home Assistant `8123` blocked from external clients.
- Trust proxy headers only from this add-on source in `trusted_proxies`.
- Do not store app secrets in git or Docker image layers.
