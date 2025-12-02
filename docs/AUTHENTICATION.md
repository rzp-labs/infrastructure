# Authentication Architecture

> **Status:** Historical design. The active deployment currently runs Traefik as an internal-only reverse proxy without a centralized IdP; Zitadel and oauth2-proxy are not deployed.

## Overview

The infrastructure uses a **single-domain authentication gateway** where:

- **Traefik** is the only externally-exposed service at `login.rzp.one`
- **Zitadel** provides identity management, accessible only internally
- **oauth2-proxy** acts as authentication middleware for all services
- All unauthenticated requests redirect to `login.rzp.one` for authentication

This architecture provides **unified SSO** across all services with **defense in depth** through network isolation.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        EXTERNAL                              │
│                                                              │
│  User → https://service.rzp.one (no auth cookie)            │
│           ↓                                                  │
│         REDIRECT to https://login.rzp.one                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    TRAEFIK (Port 443)                        │
│  - Routes login.rzp.one/ → Zitadel UI                       │
│  - Routes login.rzp.one/oauth2/* → oauth2-proxy             │
│  - Intercepts *.rzp.one → auth middleware check             │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴──────────┐
                    ↓                    ↓
         ┌──────────────────┐  ┌────────────────┐
         │  oauth2-proxy    │  │    Zitadel     │
         │  (middleware)    │←→│  (OIDC issuer) │
         │                  │  │                │
         │  Port: 4180      │  │  Port: 8080    │
         │  Internal only   │  │  Internal only │
         └──────────────────┘  └────────────────┘
                    │
                    ↓
         ┌──────────────────┐
         │  Protected       │
         │  Services        │
         │  (dashboard,     │
         │   apps, etc)     │
         └──────────────────┘
```

## Network Isolation

The architecture uses Docker networks to enforce security boundaries:

### External Network
- **Exposed**: Only Traefik (ports 80, 443)
- **Purpose**: Single external entry point for all traffic

### Traefik Network (Internal)
- **Members**: oauth2-proxy, Zitadel, all protected services
- **Purpose**: Traefik can route to internal services
- **Security**: No direct external access to services

### Zitadel Network (Internal Only)
- **Members**: Zitadel application, Zitadel database
- **Purpose**: Database isolation from other services
- **Security**: Database accessible only by Zitadel

### Socket Proxy Network
- **Members**: docker-socket-proxy, Traefik
- **Purpose**: Secure Docker API access for service discovery
- **Security**: Read-only access to Docker socket

## Authentication Flow

### Initial Request (Unauthenticated)

1. User accesses `https://traefik.rzp.one` (Traefik dashboard)
2. Traefik middleware checks for `_oauth2_proxy` cookie
3. No cookie found → Forward auth request to oauth2-proxy
4. oauth2-proxy has no valid session → Redirect to `https://login.rzp.one`
5. User sees Zitadel login page

### Login Process

1. User enters credentials at Zitadel login page
2. Zitadel validates credentials against user database
3. On success, redirects to `https://login.rzp.one/oauth2/callback?code=...`
4. oauth2-proxy exchanges code for tokens with Zitadel (OIDC flow)
5. oauth2-proxy validates tokens and creates session
6. Session cookie `_oauth2_proxy` set for `.rzp.one` domain
7. Redirect back to original URL `https://traefik.rzp.one`

### Authenticated Request

1. User accesses `https://traefik.rzp.one` (has cookie)
2. Traefik middleware checks for `_oauth2_proxy` cookie
3. Cookie found → Forward auth request to oauth2-proxy
4. oauth2-proxy validates session, responds with 202 + headers
5. Traefik adds `X-Auth-Request-*` headers to request
6. Request forwarded to backend service
7. User sees Traefik dashboard

### Single Sign-On (SSO)

Because the cookie is set for `.rzp.one`:
- Access to `https://service1.rzp.one` → Already authenticated
- Access to `https://service2.rzp.one` → Already authenticated
- No additional logins required across services

## Configuration

### Domain Strategy

All authentication uses a **single domain**: `login.rzp.one`

- **Zitadel UI**: `https://login.rzp.one/`
- **OAuth callback**: `https://login.rzp.one/oauth2/callback`
- **Cookie domain**: `.rzp.one` (all subdomains)

This simplifies DNS, SSL certificates, and user experience.

### Zitadel Configuration

**Environment Variables** (`stacks/zitadel/.env`):

```bash
# Public domain for Zitadel
ZITADEL_PUBLIC_DOMAIN=login.rzp.one

# Database connection
ZITADEL_DATABASE_POSTGRES_HOST=zitadel-db
ZITADEL_DATABASE_POSTGRES_PORT=5432
ZITADEL_DATABASE_POSTGRES_DATABASE=zitadel
ZITADEL_DATABASE_POSTGRES_USER_USERNAME=zitadel
ZITADEL_DATABASE_POSTGRES_USER_PASSWORD=<secure-password>
ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE=disable

# Admin user (created on first run)
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME=admin
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD=<secure-password>
```

**Network Configuration**:
- Connected to `traefik` network (for Traefik routing)
- Connected to `zitadel` network (for database access)
- NOT exposed on external ports

### oauth2-proxy Configuration

**Environment Variables** (`stacks/traefik/.env`):

```bash
# Provider configuration
OAUTH2_PROXY_PROVIDER=oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=https://login.rzp.one
OAUTH2_PROXY_CLIENT_ID=<zitadel-client-id>
OAUTH2_PROXY_CLIENT_SECRET=<zitadel-client-secret>

# Callback and cookie configuration
OAUTH2_PROXY_REDIRECT_URL=https://login.rzp.one/oauth2/callback
OAUTH2_PROXY_COOKIE_SECRET=<random-32-bytes>
OAUTH2_PROXY_COOKIE_DOMAINS=.rzp.one
OAUTH2_PROXY_WHITELIST_DOMAINS=.rzp.one
OAUTH2_PROXY_COOKIE_SECURE=true

# Session configuration
OAUTH2_PROXY_SESSION_COOKIE_MINIMAL=true
OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true

# Email domains (optional - restrict to specific domains)
# OAUTH2_PROXY_EMAIL_DOMAINS=*
```

**Network Configuration**:
- Connected to `traefik` network only
- Accessible via Traefik at `login.rzp.one/oauth2/*`
- NOT exposed on external ports

### Traefik Configuration

**Middleware Chain** (`stacks/traefik/config/middlewares.yml`):

```yaml
http:
  middlewares:
    # OAuth2 authentication middleware
    oauth2-auth:
      forwardAuth:
        address: "http://traefik-oauth2-proxy:4180/oauth2/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-Auth-Request-User"
          - "X-Auth-Request-Email"
          - "X-Auth-Request-Access-Token"

    # Security headers
    secure-headers:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000

    # Complete auth chain
    auth-chain:
      chain:
        middlewares:
          - oauth2-auth
          - secure-headers
```

**Router Configuration** (labels in `docker-compose.yml`):

```yaml
# Zitadel UI accessible at login.rzp.one/
labels:
  - "traefik.http.routers.zitadel.rule=Host(`login.rzp.one`)"
  - "traefik.http.routers.zitadel.entrypoints=websecure"
  - "traefik.http.routers.zitadel.tls.certresolver=cloudflare"

# oauth2-proxy accessible at login.rzp.one/oauth2/*
labels:
  - "traefik.http.routers.oauth2-proxy.rule=Host(`login.rzp.one`) && PathPrefix(`/oauth2`)"
  - "traefik.http.routers.oauth2-proxy.entrypoints=websecure"
  - "traefik.http.routers.oauth2-proxy.tls.certresolver=cloudflare"

# Protected service (Traefik dashboard)
labels:
  - "traefik.http.routers.traefik.rule=Host(`traefik.rzp.one`)"
  - "traefik.http.routers.traefik.middlewares=auth-chain"
  - "traefik.http.routers.traefik.entrypoints=websecure"
  - "traefik.http.routers.traefik.tls.certresolver=cloudflare"
```

## Setup Process

### Prerequisites

1. DNS records configured:
   - `login.rzp.one` → Server IP
   - `*.rzp.one` → Server IP (wildcard or individual subdomains)

2. SSL certificates (via Cloudflare or Let's Encrypt):
   - Traefik handles certificate acquisition automatically

### Initial Deployment

The Ansible playbooks automate the complete setup:

```bash
# Full bootstrap (first-time deployment)
make docker-bootstrap

# This runs:
# 1. Install Docker and dependencies
# 2. Create required networks
# 3. Deploy docker-socket-proxy
# 4. Deploy Zitadel and initialize database
# 5. Create OAuth application in Zitadel
# 6. Deploy oauth2-proxy with credentials
# 7. Deploy Traefik with authentication middleware
```

### Manual OAuth Application Creation

If you need to create the OAuth application manually:

1. Access Zitadel at `https://login.rzp.one` (initially via Traefik API port)
2. Login with admin credentials
3. Navigate to Organization → Applications
4. Create new application:
   - **Name**: oauth2-proxy
   - **Type**: Web Application
   - **Redirect URI**: `https://login.${DOMAIN}/oauth2/callback`
   - **Scopes**: `openid`, `profile`, `email`
5. Save the **Client ID** and **Client Secret**
6. Add credentials to `stacks/traefik/.env`
7. Restart oauth2-proxy: `docker restart traefik-oauth2-proxy`

## Testing

### Health Checks

Verify all components are functioning:

```bash
# Run comprehensive health checks
make docker-check-health

# Manual verification
curl -I https://login.rzp.one  # Should return 200 (Zitadel UI)
curl -I https://login.rzp.one/oauth2/ping  # Should return 200 (oauth2-proxy)
curl -I https://traefik.rzp.one  # Should return 302 (redirect to login)
```

### Authentication Flow Test

1. **Unauthenticated access**:
   ```bash
   curl -IL https://traefik.rzp.one
   # Should show: 302 redirect to login.rzp.one
   ```

2. **Login page accessible**:
   ```bash
   curl -I https://login.rzp.one
   # Should show: 200 OK (Zitadel login page)
   ```

3. **OAuth callback endpoint**:
   ```bash
   curl -I https://login.rzp.one/oauth2/ping
   # Should show: 200 OK (oauth2-proxy health check)
   ```

4. **Browser test**:
   - Visit `https://traefik.rzp.one` in private/incognito window
   - Should redirect to `https://login.rzp.one`
   - Login with credentials
   - Should redirect back to dashboard with valid session

### Network Isolation Verification

Verify Zitadel is NOT accessible externally:

```bash
# From external network (should fail)
curl https://your-server-ip:8080
# Connection refused or timeout

# From Traefik container (should succeed)
docker exec traefik curl http://zitadel:8080/healthz
# Returns 200 OK
```

### SSO Verification

Test single sign-on across services:

1. Login to service A (`https://service-a.rzp.one`)
2. Open new tab, access service B (`https://service-b.rzp.one`)
3. Should access service B **without** additional login
4. Cookie `_oauth2_proxy` should be present for `.rzp.one`

## Troubleshooting

### Login Loop (Constant Redirects)

**Symptom**: Redirects to login page even after successful authentication

**Causes**:
- Cookie not being set (domain mismatch)
- oauth2-proxy can't validate session
- Zitadel OIDC not accessible

**Diagnosis**:
```bash
# Check oauth2-proxy logs
docker logs traefik-oauth2-proxy

# Check cookie domain configuration
echo $OAUTH2_PROXY_COOKIE_DOMAINS  # Should be .rzp.one

# Test OIDC discovery
curl https://login.rzp.one/.well-known/openid-configuration
```

**Fix**:
- Verify `OAUTH2_PROXY_COOKIE_DOMAINS=.rzp.one` (note the leading dot)
- Ensure `OAUTH2_PROXY_REDIRECT_URL` matches exactly
- Check oauth2-proxy can reach Zitadel internally

### Zitadel Unreachable

**Symptom**: Login page returns 502 Bad Gateway

**Causes**:
- Zitadel container not running
- Zitadel database not initialized
- Network connectivity issue

**Diagnosis**:
```bash
# Check Zitadel status
docker ps | grep zitadel
docker logs zitadel
docker logs zitadel-db

# Test internal connectivity
docker exec traefik curl http://zitadel:8080/healthz
```

**Fix**:
```bash
# Restart Zitadel and database
docker restart zitadel-db
sleep 5
docker restart zitadel

# Check logs for initialization
docker logs -f zitadel
```

### oauth2-proxy Not Starting

**Symptom**: oauth2-proxy container exits immediately

**Causes**:
- Invalid OIDC configuration
- Missing environment variables
- Bad client credentials

**Diagnosis**:
```bash
# Check oauth2-proxy logs
docker logs traefik-oauth2-proxy

# Verify environment variables
docker exec traefik-oauth2-proxy env | grep OAUTH2
```

**Fix**:
```bash
# Verify all required variables in .env
cd /opt/stacks/traefik
grep OAUTH2 .env

# Recreate oauth2-proxy with correct config
docker-compose up -d --force-recreate traefik-oauth2-proxy
```

### Services Not Protected

**Symptom**: Can access services without authentication

**Causes**:
- Middleware not applied to router
- Traefik configuration not loaded
- Wrong middleware chain

**Diagnosis**:
```bash
# Check Traefik dashboard
curl https://traefik.rzp.one/api/http/routers

# Verify middleware configuration loaded
docker exec traefik cat /etc/traefik/config/middlewares.yml
```

**Fix**:
```bash
# Ensure middleware labels on service
traefik.http.routers.<service>.middlewares=auth-chain

# Restart Traefik to reload config
docker restart traefik
```

## Security Considerations

### Cookie Security

The `_oauth2_proxy` cookie is secured with:
- **HttpOnly**: Prevents JavaScript access
- **Secure**: Only sent over HTTPS
- **SameSite**: CSRF protection
- **Domain**: `.rzp.one` (all subdomains)

Regenerate cookie secret periodically:
```bash
python -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

### Client Secret Rotation

Rotate OAuth client secrets periodically:

1. Create new application in Zitadel
2. Update `OAUTH2_PROXY_CLIENT_ID` and `OAUTH2_PROXY_CLIENT_SECRET`
3. Restart oauth2-proxy
4. Deactivate old application in Zitadel

### Network Isolation

Zitadel should **never** be directly accessible externally:
- No port mappings on Zitadel container
- Only connected to internal networks
- Only accessible via Traefik routing

Verify with:
```bash
nmap -p 8080 your-server-ip  # Should show: closed or filtered
```

### Emergency Access

If authentication is completely broken:

1. SSH to server
2. Temporarily disable auth middleware:
   ```bash
   cd /opt/stacks/traefik/config
   cp middlewares.yml middlewares.yml.backup
   # Comment out auth-chain middleware
   docker restart traefik
   ```
3. Access services directly via localhost
4. Fix authentication issue
5. Restore middleware and restart Traefik

## References

- [Zitadel Documentation](https://zitadel.com/docs)
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Traefik ForwardAuth Middleware](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
