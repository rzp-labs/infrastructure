# Traefik Stack

Traefik v3 reverse proxy with automatic SSL certificates via the Cloudflare DNS-01
challenge. This stack now operates **entirely inside the homelab network** – no
ingress ports are exposed on the router – and provides TLS termination plus
service discovery for other stacks that share the `traefik` Docker network.

## Overview

Traefik is responsible for:

- Issuing/renewing wildcard certificates using Cloudflare DNS
- Routing internal requests based on Docker labels
- Applying baseline HTTP security headers
- Optionally restricting routes to internal CIDR ranges via middleware

Because the router blocks inbound ports, all access must originate from inside
the homelab network (or via an outbound tunnel/VPN established elsewhere).

```
Internal Client ──► Traefik (proxy network) ──► Target service container
                         │
                         └─► Cloudflare DNS API (ACME challenge)
```

## Environment Variables

Create `.env` in this directory with the Cloudflare token and homelab domain
information:

```bash
# Cloudflare DNS Challenge
CF_DNS_API_TOKEN=your_cloudflare_dns_api_token
ACME_EMAIL=you@example.com

# Domain + timezone metadata
DOMAIN=homelab.example
TZ=America/Phoenix
```

The Cloudflare token needs `Zone:DNS:Edit` permission for the target zone. No
other OAuth or authentication secrets are required now that Zitadel is removed.

## Router Labels

Every service that should be reachable through Traefik must:

1. Join the `traefik` Docker network
2. Provide labels describing its router and target port

Example minimal configuration:

```yaml
services:
  my-app:
    image: ghcr.io/org/my-app:latest
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.${DOMAIN}`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=cloudflare"
      - "traefik.http.routers.my-app.middlewares=secure-headers@file"
      - "traefik.http.services.my-app.loadbalancer.server.port=8080"
```

For routes that must remain limited to the management LAN, chain the `internal`
whitelist middleware defined in `config/middlewares.yml`:

```yaml
- "traefik.http.routers.internal-app.middlewares=internal@file,secure-headers@file"
```

## Middlewares

`config/middlewares.yml` ships with two reusable middlewares:

- **secure-headers** – Enables HTTP→HTTPS redirect and strict transport security
- **internal** – Whitelists traffic to `10.0.0.0/24` (tune for your LAN CIDR)

Feel free to extend this file with additional chains (rate limiters, IP bans,
etc.) based on local requirements.

## Deployment

```bash
make docker-deploy stack=traefik
```

The stack mounts `/opt/stacks/traefik/acme.json` on the host; ensure that file
exists and is `chmod 600` as part of the deployment.

## Validation

```bash
# Confirm container is running
docker ps | grep traefik

# Check certificate resolver status
docker logs traefik | grep -i acme

# Inspect routers/middlewares
docker exec traefik traefik api --summary
```

Because the router blocks inbound connections, you will typically test from a
machine already on the homelab network (e.g., `curl https://traefik.DOMAIN`).

## Tips & Troubleshooting

- **Certificate errors** – Verify Cloudflare token permissions and that
  `acme.json` is writable by the container (root:root, 0600).
- **Routing issues** – Ensure the downstream service joined the `traefik`
  network and that `traefik.enable=true` label is present.
- **Need temporary exposure** – Prefer wireguard/TAILSCALE/bastion tunnels over
  opening router ports. Traefik itself no longer binds host ports.

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cloudflare DNS API](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records)
