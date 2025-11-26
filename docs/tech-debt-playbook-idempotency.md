# Tech Debt: Playbook Idempotency and Atomicity

**Created:** 2025-11-24
**Priority:** Medium
**Status:** Open

## Summary

The Ansible playbooks for Docker deployment are not fully idempotent or atomic. Running them multiple times or in different orders can leave the system in inconsistent states.

## Issues Identified

### 1. Inconsistent Project Names
- `docker-bootstrap.yml` uses project name `stacks`
- `docker-deploy-services.yml` uses project name `services`
- This causes container name conflicts when containers exist from different projects
- Docker Compose only manages containers within its own project, leaving orphans

### 2. Error Suppression
- `|| true` patterns swallow critical errors (e.g., volume deletion failures)
- `ignore_errors: true` used on operations that should fail fast
- No verification that destructive operations actually succeeded

### 3. Path Resolution Issues
- Relative paths in docker-compose files resolve differently depending on working directory
- `./config` resolved to `/opt/stacks/config` instead of `/opt/stacks/zitadel/config`
- Fixed by using paths relative to compose file location from project root

### 4. Missing Pre-flight Checks
- Container user permissions not verified before operations that require write access
- No check for existing containers before creating new ones
- No verification that required services are healthy before dependent operations

### 5. Missing Post-flight Verification
- Volume deletion not verified after removal command
- Container removal not verified after stop command
- Health checks used wrong endpoints (external vs internal)

### 6. Health Check Issues
- Health checks tried to reach external URLs through Traefik before Traefik was deployed
- Zitadel `ready` command doesn't work with `--tlsMode external` configuration
- Distroless container images have no shell tools for custom health checks

## Recommended Fixes

### Short-term (Workarounds Applied)
- [x] Fixed volume path in zitadel docker-compose.yml
- [x] Added `user: "0"` to run Zitadel as root
- [x] Replaced broken health check with log-based verification
- [x] Added container write test before Zitadel deployment
- [x] Added explicit verification after volume/container deletion

### Long-term (Refactor Required)

1. **Unify project names** - Use single project name `stacks` across all playbooks

2. **Add pre-flight checks**
   - Verify no conflicting containers exist
   - Verify required networks exist
   - Verify disk space and permissions

3. **Add post-flight verification**
   - Verify containers are running after deployment
   - Verify volumes are deleted after removal
   - Verify services respond to health checks

4. **Remove error suppression**
   - Replace `|| true` with proper error handling
   - Use `failed_when` conditions instead of `ignore_errors`
   - Add rescue blocks for cleanup on failure

5. **Add cleanup tasks**
   - Remove orphaned containers before deployment
   - Add `--remove-orphans` flag to compose commands
   - Create dedicated cleanup playbook

6. **Improve health checks**
   - Use internal endpoints for pre-Traefik checks
   - Add proper healthcheck to docker-compose files
   - Verify API authentication works, not just container running

## Files Affected

- `playbooks/docker-bootstrap.yml`
- `playbooks/docker-deploy-services.yml`
- `playbooks/docker-deploy-bootstrap.yml`
- `playbooks/zitadel-reset.yml`
- `stacks/zitadel/docker-compose.yml`
- `stacks/traefik/docker-compose.yml`

## Related Issues

- Container name conflict: `traefik-oauth2-proxy` exists from old project
- Zitadel partial initialization when PAT write fails
- Volume data persists after "successful" deletion
