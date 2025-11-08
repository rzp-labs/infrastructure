# SSH Setup for DevContainer Ansible Access

This guide explains how to use SSH agent forwarding to enable Ansible execution from the DevContainer to homelab hosts, maintaining SSH key security while supporting multiple development machines.

## Architecture

The infrastructure uses **SSH Agent Forwarding** to authenticate Ansible SSH connections without storing private keys in containers or the repository:

```
1Password SSH Agent (macOS Host)
    ↓ SSH_AUTH_SOCK forwarded to container
DevContainer (Ansible)
    ↓ SSH connection using forwarded agent
Target Homelab Hosts
```

**Key Benefits:**
- ✅ Zero private keys in containers or repository
- ✅ Works across multiple development hosts (home + office)
- ✅ Leverages 1Password SSH agent natively
- ✅ Public repository safe (no secrets or host-specific config)
- ✅ Simple maintenance (standard SSH mechanisms)

## Prerequisites

### 1. 1Password SSH Agent Setup

Enable SSH agent in 1Password (macOS):

1. Open 1Password
2. Settings → Developer
3. Enable "Use the SSH agent"
4. Enable "Integrate with 1Password CLI"

Add your SSH keys to 1Password:
- SSH keys stored in 1Password vaults sync across all your Macs
- Keys are available on any macOS host where you're signed in
- No manual key copying between machines needed

### 2. DevContainer with SSH Agent Forwarding

The DevContainer configuration already includes SSH agent forwarding via the `ghcr.io/devcontainers/features/sshd:1` feature. VSCode automatically forwards `SSH_AUTH_SOCK` when you open the DevContainer.

**Verify agent forwarding works:**
```bash
# Inside DevContainer
echo $SSH_AUTH_SOCK  # Should show: /tmp/auth-agent.../listener.sock
ssh-add -l           # Lists keys from 1Password agent
```

## First-Time Setup

### 1. Configure Inventory

Create your inventory from the template:

```bash
cd infrastructure
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit `inventory/hosts.yml`:

```yaml
---
all:
  children:
    homelab:
      hosts:
        debian-docker:
          ansible_host: 10.0.0.100  # Your VM's IP
          ansible_user: admin        # Your SSH user
          ansible_python_interpreter: /usr/bin/python3
          # SSH agent forwarding (uses 1Password SSH agent)
          ansible_ssh_common_args: >-
            -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
            -o IdentitiesOnly=yes
            -o StrictHostKeyChecking=yes
            -o UserKnownHostsFile={{ playbook_dir }}/../.ssh/known_hosts
```

**Configuration explained:**
- `IdentityAgent=$SSH_AUTH_SOCK` - Use forwarded 1Password agent
- `IdentitiesOnly=yes` - Only try keys from agent (prevents key exhaustion)
- `StrictHostKeyChecking=yes` - Verify host keys for MITM protection
- `UserKnownHostsFile=.ssh/known_hosts` - Workspace-local known hosts file

### 2. Accept Host Keys

On first connection to each homelab host, you must accept its SSH host key fingerprint:

```bash
make ping
```

**Expected output on first run:**
```
The authenticity of host '10.0.0.100' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Type `yes` to accept. The host key is saved to `infrastructure/.ssh/known_hosts` (gitignored).

**All future connections verify against this saved key** - protecting against man-in-the-middle attacks.

## Usage

### Daily Workflow

With setup complete, Ansible commands just work:

```bash
# Test connectivity
make ping

# Deploy a stack
make docker-deploy stack=traefik

# Run ad-hoc commands
uv run ansible homelab -a "docker ps"
uv run ansible homelab -a "df -h"
```

The SSH agent handles authentication automatically using your 1Password SSH keys.

## Multi-Host Development

The same configuration works seamlessly across multiple development machines:

**On First Mac (Office):**
1. Complete first-time setup (inventory + host keys)
2. Commit changes to git
3. SSH connections work via 1Password agent

**On Second Mac (Home):**
1. Git pull to get inventory
2. Open in DevContainer
3. Run `make ping` to accept host keys (one-time)
4. SSH connections work via 1Password agent

**Why this works:**
- Inventory configuration is portable (no machine-specific paths)
- SSH keys come from 1Password (synced across your Macs)
- Known hosts are workspace-local (`.ssh/known_hosts` gitignored)
- Each workspace has its own known hosts file

## Troubleshooting

### "Permission denied (publickey)"

**Symptom:** SSH authentication fails

**Check:**
```bash
# 1. Verify SSH agent is forwarded
echo $SSH_AUTH_SOCK
# Should show: /tmp/auth-agent.../listener.sock

# 2. List available keys
ssh-add -l
# Should list your 1Password SSH keys

# 3. Test direct SSH (bypassing Ansible)
ssh admin@10.0.0.100
```

**Solutions:**
- If `SSH_AUTH_SOCK` is empty: Restart DevContainer
- If `ssh-add -l` shows no keys: Check 1Password SSH agent is enabled
- If direct SSH works but Ansible doesn't: Check inventory `ansible_ssh_common_args`

### "Host key verification failed"

**Symptom:** `UNREACHABLE! => {"changed": false, "msg": "Host key verification failed.", ...}`

**Cause:** Host key not in `.ssh/known_hosts` or host key changed

**Solutions:**
- First connection: Run `make ping` and accept host key
- Host key changed legitimately: Remove old key and re-accept
  ```bash
  ssh-keygen -R 10.0.0.100
  make ping  # Accept new key
  ```
- If host key changed unexpectedly: **DO NOT PROCEED** - possible MITM attack

### "Too many authentication failures"

**Symptom:** SSH tries many keys before failing

**Cause:** 1Password agent offers all keys, hitting server's MaxAuthTries limit

**Solution:** Add `IdentitiesOnly=yes` to inventory (already in example):
```yaml
ansible_ssh_common_args: >-
  -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
  -o IdentitiesOnly=yes  # Prevents trying all keys
```

### Agent not forwarded in DevContainer

**Symptom:** `$SSH_AUTH_SOCK` is empty inside container

**Check:**
1. Verify VSCode Dev Containers extension is installed
2. Ensure opening via "Reopen in Container" (not manual docker run)
3. Check `.devcontainer/devcontainer.json` has sshd feature

**Solution:**
```bash
# Rebuild DevContainer
Cmd+Shift+P → "Dev Containers: Rebuild Container"
```

### Different keys on different hosts

**Scenario:** Office and home Macs have different SSH keys in 1Password

**Solution:** This works automatically! Each host's 1Password agent provides its own keys. Ensure target VMs trust both public keys:

```bash
# On homelab VM, add both public keys to authorized_keys
~/.ssh/authorized_keys
```

Copy your public keys from each Mac:
```bash
# On office Mac
ssh-add -L  # Shows public keys

# On home Mac
ssh-add -L  # Shows public keys (may be different)
```

## Security Model

### What's Protected

**Private keys never exposed:**
- NOT in DevContainer filesystem
- NOT in git repository
- NOT in Docker images
- Keys stay in 1Password vault, agent provides authentication

**MITM protection:**
- `StrictHostKeyChecking=yes` enforces known host verification
- First connection requires manual fingerprint acceptance
- Subsequent connections validate against saved key
- Connection fails if host key changes

### Trust Boundaries

**Trusted:**
- macOS host system
- 1Password application and SSH agent
- VSCode Dev Containers extension

**Semi-trusted:**
- DevContainer (no private keys, but uses forwarded agent)
- Temporary SSH agent socket (read-only, process-isolated)

**Untrusted:**
- Public git repository
- Container images
- Network between machines

### Known Hosts Storage

The `.ssh/known_hosts` file is **workspace-local and gitignored**:

**Why gitignored:**
- Contains target host fingerprints (not secret, but host-specific)
- Each developer may target different homelab hosts
- Prevents conflicts when multiple people work on same repo

**Location:** `infrastructure/.ssh/known_hosts`

**Backup:** Not needed - can regenerate by running `make ping`

## Advanced Configuration

### Custom SSH Options

Add SSH options in inventory per-host:

```yaml
hosts:
  special-host:
    ansible_host: 192.168.1.50
    ansible_user: special
    ansible_ssh_common_args: >-
      -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
      -o IdentitiesOnly=yes
      -o Port=2222
      -o ConnectTimeout=10
```

### Multiple Target Environments

Use inventory groups for different environments:

```yaml
all:
  children:
    homelab-prod:
      hosts:
        prod-vm:
          ansible_host: 10.0.0.100
    homelab-staging:
      hosts:
        staging-vm:
          ansible_host: 10.0.0.101
```

Deploy to specific environment:
```bash
ansible-playbook playbooks/deploy-stack.yml -e stack=traefik -l homelab-staging
```

### SSH Config Integration

You can use SSH config aliases:

**~/.ssh/config on host:**
```
Host homelab-vm
    HostName 10.0.0.100
    User admin
    IdentityAgent ~/.1password/agent.sock
```

**Inventory:**
```yaml
ansible_host: homelab-vm  # Uses SSH config
```

## Philosophy Alignment

This SSH setup follows the infrastructure project's core principles:

**Ruthless Simplicity:**
- Standard SSH agent forwarding (no custom tools)
- Leverages existing 1Password SSH agent
- No encryption layers or key management scripts

**Security-First:**
- Private keys never in containers or repository
- Strict host key checking prevents MITM attacks
- Agent provides authentication without key exposure

**Trust in Emergence:**
- Simple components (SSH agent, VSCode forwarding, Ansible)
- Well-tested patterns (SSH agent forwarding widely used)
- Standard protocols (no custom encryption)

**Present-Moment Focus:**
- Solves current need (1Password + devpods + multiple hosts)
- No over-engineering for hypothetical future scenarios
- Handles actual constraints (public repo, two macOS hosts)

## References

- [1Password SSH Agent Documentation](https://developer.1password.com/docs/ssh/)
- [VSCode: SSH agent forwarding in Dev Containers](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials#_using-ssh-keys)
- [Ansible SSH connection type](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html)
- [OpenSSH: SSH Agent](https://www.openssh.com/agent.html)
