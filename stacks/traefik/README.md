# Traefik Stack

Traefik v3 reverse proxy with automatic SSL via Cloudflare DNS challenge and integrated oauth2-proxy for authentication.

## Overview

Traefik serves as the **single external entry point** for all infrastructure services, providing:
- Automatic HTTPS with Let's Encrypt via Cloudflare DNS-01 challenge
- Authentication gateway using oauth2-proxy + Zitadel OIDC
- Automatic service discovery via Docker labels
- Centralized routing and SSL termination

## Architecture

```
External → Traefik (443) → oauth2-proxy → Protected Services
                  ↓
              Zitadel (OIDC)
```

**Key Features**:
- Only service exposed externally (ports 80/443)
- oauth2-proxy runs as sidecar for authentication middleware
- Automatic SSL certificate acquisition and renewal
- Docker Socket Proxy for secure Docker API access

## Domain Configuration

Single domain authentication strategy:
- **Login/Auth**: `login.rzp.one` (Zitadel UI + oauth2-proxy callback)
- **Services**: `*.rzp.one` (all protected services)
- **Cookie domain**: `.rzp.one` (SSO across all subdomains)

## Environment Variables

Create `.env` file with:

```bash
# Cloudflare DNS Challenge
CF_DNS_API_TOKEN=your_cloudflare_dns_api_token
CF_API_EMAIL=your_email@example.com
DOMAIN=rzp.one
TZ=America/Phoenix

# OAuth2 Proxy Configuration
OAUTH2_PROXY_PROVIDER=oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=https://login.${DOMAIN}
OAUTH2_PROXY_CLIENT_ID=<from-zitadel-app>
OAUTH2_PROXY_CLIENT_SECRET=<from-zitadel-app>
OAUTH2_PROXY_COOKIE_SECRET=<random-32-bytes>
OAUTH2_PROXY_REDIRECT_URL=https://login.${DOMAIN}/oauth2/callback
OAUTH2_PROXY_COOKIE_DOMAINS=.${DOMAIN}
OAUTH2_PROXY_WHITELIST_DOMAINS=.${DOMAIN}
OAUTH2_PROXY_COOKIE_SECURE=true
OAUTH2_PROXY_SESSION_COOKIE_MINIMAL=true
OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
```

**Generate Cookie Secret**:
```bash
python -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

## Service Configuration

### Router Labels

Protect a service with authentication:

```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.${DOMAIN}`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=cloudflare"
      - "traefik.http.routers.my-app.middlewares=auth-chain"
      - "traefik.http.services.my-app.loadbalancer.server.port=80"
```

### Public Service (No Auth)

For publicly accessible services:

```yaml
labels:
  - "traefik.http.routers.public-app.middlewares=secure-headers"
```

## Middleware Chain

Authentication middleware defined in `config/middlewares.yml`:

```yaml
http:
  middlewares:
    # OAuth2 authentication
    oauth2-auth:
      forwardAuth:
        address: "http://traefik-oauth2-proxy:4180/oauth2/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-Auth-Request-User"
          - "X-Auth-Request-Email"

    # Security headers
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000

    # Complete authentication chain
    auth-chain:
      chain:
        middlewares:
          - oauth2-auth
          - secure-headers
```

## Deployment

### Prerequisites

1. **DNS Records**:
   - `login.rzp.one` → Server IP
   - `*.rzp.one` → Server IP (or individual service subdomains)

2. **Cloudflare API Token**:
   - Create token with `Zone:DNS:Edit` permission
   - Add to `.env` as `CF_DNS_API_TOKEN`

3. **Zitadel OAuth Application**:
   - Created automatically by bootstrap process
   - Or create manually in Zitadel UI

### Deploy Stack

```bash
make docker-deploy stack=traefik
```

### Verify Deployment

```bash
# Check Traefik is running
docker ps | grep traefik

# Check oauth2-proxy is running
docker ps | grep oauth2-proxy

# Check Traefik can reach oauth2-proxy
docker exec traefik curl http://traefik-oauth2-proxy:4180/ping

# Check logs
docker logs traefik
docker logs traefik-oauth2-proxy
```

## Testing Authentication

### Unauthenticated Access

```bash
curl -IL https://traefik.rzp.one
# Should redirect to login.rzp.one
```

### OAuth Callback Endpoint

```bash
curl -I https://login.rzp.one/oauth2/ping
# Should return 200 OK
```

### Login Flow

1. Visit protected service: `https://traefik.rzp.one`
2. Redirected to: `https://login.rzp.one`
3. Login with Zitadel credentials
4. Redirected back with valid session cookie
5. Access granted to all `*.rzp.one` services (SSO)

## Troubleshooting

### Certificates Not Generated

**Symptom**: SSL errors when accessing services

**Check**:
```bash
# Verify Cloudflare API token
docker logs traefik | grep -i cloudflare

# Check acme.json permissions
ls -la /opt/stacks/traefik/acme.json
# Should be 600 (-rw-------)

# Verify DNS propagation
dig +short login.rzp.one
```

### Authentication Loop

**Symptom**: Redirects to login repeatedly after successful authentication

**Check**:
```bash
# Verify cookie domain configuration
docker exec traefik-oauth2-proxy env | grep COOKIE_DOMAINS
# Should be .rzp.one (note the leading dot)

# Check oauth2-proxy can reach Zitadel
docker exec traefik-oauth2-proxy curl https://login.rzp.one/.well-known/openid-configuration
```

### Services Not Protected

**Symptom**: Can access services without authentication

**Check**:
```bash
# Verify middleware applied to router
docker logs traefik | grep -i middleware

# Check Traefik dashboard for router configuration
curl https://traefik.rzp.one/api/http/routers
```

## Health Monitoring

### Endpoints

- **Traefik API**: `http://localhost:8080/api/` (internal only)
- **oauth2-proxy Health**: `http://localhost:4180/ping` (internal only)

### Prometheus Metrics

Traefik exposes Prometheus metrics at:
- `http://localhost:8080/metrics`

## Security Considerations

### Network Isolation

- **External**: Traefik only (ports 80/443)
- **Traefik Network**: Internal services accessible only via Traefik routing
- **Socket Proxy**: Read-only Docker API access

### SSL Configuration

- Automatic redirect HTTP → HTTPS
- HSTS header enabled (1 year)
- Certificates stored in `acme.json` (mode 600)
- Cloudflare DNS-01 challenge (no port 80 required)

### Authentication Security

- HttpOnly cookies (prevent XSS)
- Secure flag (HTTPS only)
- SameSite attribute (CSRF protection)
- Cookie secret rotation recommended quarterly

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Cloudflare DNS API](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records)
- [Authentication Architecture](../../docs/AUTHENTICATION.md)
