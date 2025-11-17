# SSH Directory

This directory stores SSH-related files for the infrastructure workspace.

## Purpose

The `.ssh/` directory contains **workspace-local SSH configuration** used by Ansible when connecting to homelab hosts. This keeps SSH state isolated from your system-wide SSH config while maintaining security.

## Files

### `known_hosts`

**Purpose:** Stores SSH host key fingerprints for target homelab hosts.

**Format:** OpenSSH known_hosts format (one line per host)
```
<hostname-or-ip> <key-type> <public-key-base64>
```

**Example:**
```
10.0.0.100 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGq4fN0WX...
```

**Generation:** Automatically created on first SSH connection via `make ping`

**Security Considerations:**
- **Gitignored** - Each workspace maintains its own known hosts
- **MITM protection** - Subsequent connections verify against stored keys
- **Per-workspace** - Different workspaces can target different hosts
- **Regenerable** - Can be safely deleted and recreated

**When to regenerate:**
- Host key changed legitimately (VM reinstalled, SSH daemon reconfigured)
- Working with a different set of homelab hosts
- Switching between production and staging environments

**How to regenerate:**
```bash
rm .ssh/known_hosts
make ping  # Accept new host keys
```

### `.gitignore`

Ensures SSH files (except this README) are never committed to git.

**What's ignored:**
- `known_hosts` - Host-specific, not suitable for version control
- Any private keys (if accidentally placed here)
- Any other SSH runtime files

**Why ignore:**
- **No secrets in repo** - Prevents accidental key commits
- **Host-specific** - Each developer may have different target hosts
- **Avoid conflicts** - Multiple developers don't conflict on known_hosts

## SSH Agent Forwarding

This workspace uses **SSH agent forwarding** instead of storing private keys:

```
1Password SSH Agent (macOS)
    ↓ SSH_AUTH_SOCK forwarded by VSCode
DevContainer
    ↓ Ansible uses forwarded agent
Target Hosts
```

**What this means:**
- **No private keys in this directory** - Authentication via forwarded agent
- **No private keys in container** - Keys stay in 1Password vault
- **No private keys in repo** - Public repository safe

See [docs/SSH_SETUP.md](../docs/SSH_SETUP.md) for complete SSH configuration guide.

## Ansible Configuration

The `ansible.cfg` file references this directory:

```ini
[defaults]
# Use workspace-local known_hosts
host_key_checking = True
```

The inventory file specifies known_hosts location:

```yaml
ansible_ssh_common_args: >-
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile={{ playbook_dir }}/../.ssh/known_hosts
```

**Key behaviors:**
- `StrictHostKeyChecking=yes` - Always verify host keys
- Workspace-relative path - Works from any playbook directory
- Jinja2 template - Resolves playbook directory at runtime

## Troubleshooting

### "Host key verification failed"

**Cause:** Host key not in `known_hosts` or host key changed

**Solution:**
```bash
# First connection
make ping  # Accept host key when prompted

# Host key changed (legitimate)
ssh-keygen -R 10.0.0.100  # Remove old key
make ping  # Accept new key
```

### "No such file or directory: .ssh/known_hosts"

**Cause:** First time running Ansible in this workspace

**Solution:** This is normal! Run `make ping` to create the file:
```bash
make ping
# Type 'yes' when prompted to accept host key
# File .ssh/known_hosts is created automatically
```

### "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"

**Cause:** Host key changed since last connection

**Critical decision:**

**If host key changed legitimately** (VM reinstalled, SSH reconfigured):
```bash
ssh-keygen -R 10.0.0.100
make ping  # Accept new key
```

**If host key changed unexpectedly:**
```
⚠️ DO NOT PROCEED ⚠️
This may indicate a man-in-the-middle attack.
Verify the host's authenticity through an alternate channel.
```

### Permissions errors

If you see permission errors on SSH files:

```bash
# Fix directory permissions
chmod 700 .ssh

# Fix known_hosts permissions
chmod 600 .ssh/known_hosts
```

The `post-create.sh` DevContainer script sets these automatically, but manual intervention may be needed if files are created outside the normal flow.

## Security Model

### What's Protected

**MITM Prevention:**
- First connection: Manual fingerprint verification required
- Subsequent connections: Automatic verification against `known_hosts`
- Connection fails if host key doesn't match

**Private Key Protection:**
- No private keys in this directory (agent forwarding used)
- No private keys in container filesystem
- No private keys in git repository
- Keys remain in 1Password vault

### Trust Model

**Trusted:**
- macOS host system (where 1Password runs)
- 1Password SSH agent (provides keys securely)
- VSCode Dev Containers (forwards SSH_AUTH_SOCK)

**Workspace-local (.ssh/):**
- `known_hosts` - Contains public host keys (not secret)
- Isolated per workspace (not shared across projects)
- Gitignored (not synced to remote repository)

**Untrusted:**
- Public git repository (nothing sensitive committed)
- Container images (no secrets baked in)
- Network between hosts (MITM protection via known_hosts)

## Best Practices

### DO

✅ Run `make ping` before first deployment in a new workspace
✅ Verify host key fingerprints on first connection
✅ Use workspace-local known_hosts (this directory)
✅ Rely on SSH agent forwarding for authentication
✅ Keep this directory gitignored

### DON'T

❌ Commit known_hosts to git (host-specific, causes conflicts)
❌ Store private keys in this directory (use agent forwarding)
❌ Share known_hosts between workspaces (each workspace independent)
❌ Disable StrictHostKeyChecking (defeats MITM protection)
❌ Accept host key changes without verification (security risk)

## Related Documentation

- [docs/SSH_SETUP.md](../docs/SSH_SETUP.md) - Complete SSH configuration guide
- [1Password SSH Agent](https://developer.1password.com/docs/ssh/) - SSH agent setup
- [OpenSSH known_hosts](https://man.openbsd.org/sshd#SSH_KNOWN_HOSTS_FILE_FORMAT) - File format specification
