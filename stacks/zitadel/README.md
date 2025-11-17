# Zitadel Stack

Zitadel identity and access management platform configured for internal-only access via Traefik routing.

## Overview

Zitadel provides OIDC-based authentication for all infrastructure services. It runs on **internal networks only** and is accessible externally only through Traefik routing at `login.rzp.one`.

## Architecture

```
External → Traefik → Zitadel (internal)
                       ↓
                 PostgreSQL (internal)
```

**Security Model**:
- No external port exposure
- Only accessible via Traefik routing
- Isolated database network
- OIDC provider for oauth2-proxy

## Environment Variables

Create `.env` file with:

```bash
# Public Domain
ZITADEL_PUBLIC_DOMAIN=login.rzp.one

# Database Configuration
ZITADEL_DATABASE_POSTGRES_HOST=zitadel-db
ZITADEL_DATABASE_POSTGRES_PORT=5432
ZITADEL_DATABASE_POSTGRES_DATABASE=zitadel
ZITADEL_DATABASE_POSTGRES_USER_USERNAME=zitadel
ZITADEL_DATABASE_POSTGRES_USER_PASSWORD=<secure-password>
ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE=disable
ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME=postgres
ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD=<secure-password>
ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE=disable

# Initial Admin User
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME=admin
ZITADEL_FIRSTINSTANCE_ORG_HUMAN_PASSWORD=<secure-password>

# Masterkey (encryption)
ZITADEL_MASTERKEY=<random-32-bytes>
```

**Generate Secure Passwords**:
```bash
# For database passwords
openssl rand -base64 32

# For masterkey
openssl rand -base64 32
```

## Network Configuration

Zitadel connects to two Docker networks:

- **traefik**: For Traefik routing (external access)
- **zitadel**: For database access (internal only)

PostgreSQL connects only to the `zitadel` network for isolation.

## OAuth Application Setup

### Automatic Setup (Recommended)

The bootstrap playbook creates the OAuth application automatically:

```bash
make docker-bootstrap
```

### Manual Setup

1. Access Zitadel UI: `https://login.rzp.one`
2. Login with admin credentials
3. Navigate to: Organization → Applications
4. Create new application:
   - Name: `oauth2-proxy`
   - Type: Web Application
   - Redirect URI: `https://login.rzp.one/oauth2/callback`
   - Scopes: `openid`, `profile`, `email`
5. Save Client ID and Client Secret
6. Update `/opt/stacks/traefik/.env` with credentials
7. Restart oauth2-proxy: `docker restart traefik-oauth2-proxy`

## Deployment

```bash
make docker-deploy stack=zitadel
```

### Verify Deployment

```bash
# Check containers running
docker ps | grep zitadel

# Check database initialized
docker logs zitadel-db

# Check Zitadel started
docker logs zitadel

# Verify internal accessibility
docker exec traefik curl http://zitadel:8080/healthz

# Verify external inaccessibility (should fail)
curl http://YOUR-SERVER-IP:8080
```

## User Management

### Create New User

1. Access Zitadel UI
2. Navigate to: Users → Create User
3. Enter user details
4. Set initial password
5. User can login at `https://login.rzp.one`

### Password Reset

Users can reset passwords via the login page:
1. Click "Forgot password?" at `https://login.rzp.one`
2. Email will be sent (requires email configuration)

## Troubleshooting

### Zitadel Not Starting

```bash
# Check database connectivity
docker logs zitadel-db
docker exec zitadel ping -c 3 zitadel-db

# Check database initialization
docker exec zitadel-db psql -U postgres -d zitadel -c "\dt"

# Restart in order
docker restart zitadel-db
sleep 5
docker restart zitadel
```

### Login Fails

```bash
# Check OIDC discovery
curl https://login.rzp.one/.well-known/openid-configuration

# Verify user exists
docker exec zitadel-db psql -U postgres -d zitadel -c "SELECT * FROM users;"
```

### External Access Test

Verify Zitadel is NOT accessible externally:

```bash
# From external network (should fail)
nmap -p 8080 YOUR-SERVER-IP

# From Traefik container (should succeed)
docker exec traefik curl http://zitadel:8080/healthz
```

## References

- [Zitadel Documentation](https://zitadel.com/docs)
- [OIDC Configuration](https://zitadel.com/docs/guides/integrate/oauth-recommended-flows)
- [Authentication Architecture](../../docs/AUTHENTICATION.md)
