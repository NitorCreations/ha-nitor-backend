# Nitor Home Assistant Add-ons

Public Home Assistant add-on repository for Nitor-maintained add-ons.

## Add this repository to Home Assistant

1. Open **Settings -> Add-ons -> Add-on Store**.
2. Open the three-dot menu and choose **Repositories**.
3. Add:
   - `https://github.com/NitorCreations/ha-nitor-backend`

## Included add-ons

- `nitor_auth_proxy` - Java authentication proxy with Entra auth, group gating, and header forwarding for Home Assistant.

## Security model

- Runtime secrets only (add-on options), no secrets in git.
- Cookie secret persisted in add-on `/data` and generated on first start.
- TLS cert and key read from Home Assistant `/ssl` using `certfile` and `keyfile` options.

## Home Assistant configuration

After installing and starting `nitor_auth_proxy`, configure Home Assistant to trust only this proxy path.

1. Enable reverse proxy support in `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.30.33.0/24
```

Adjust `trusted_proxies` to the actual source network/address that reaches Home Assistant from the add-on. Keep this narrow.

2. Configure header-based auth provider in Home Assistant to use `x-ha-user` as username.
   - Install your header-auth integration (for example `hass-auth-header`) and set:
     - username header: `x-ha-user`
   - Keep Home Assistant admin users explicit and controlled.

3. Keep network bypass closed.
   - Block direct external access to Home Assistant `8123` at Proxmox/firewall level.
   - Allow users in through the proxy endpoint only.

4. Ensure proxy policy matches your access model.
   - Group gate with `allowed_groups_regex`.
   - Confirm forwarded headers include:
     - `x-ha-user`
     - `x-ha-groups`
     - optional `x-ha-id`

## Verification checklist

- User can log in through proxy and is mapped to a unique HA user.
- Unauthorized groups are denied before reaching Home Assistant.
- Direct `8123` access from normal clients is blocked.
