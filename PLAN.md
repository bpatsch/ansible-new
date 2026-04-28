# Ansible Repo Restructure Plan

## Goal

Restructure the existing role fragments into the clean layout specified in REQUIREMENTS.md.

## Current State (what exists)

| Path | What it is |
|---|---|
| `common/` | Role at repo root — tasks use `include_tasks`, no tags, no bootstrap split |
| `deploy-scripts/` | Root-level role: copies `kuma` and `shutdown_once_download_finished.py` to `/usr/local/bin` |
| `roles/autorestic/` | Backup role wrapping `dbrennand.autorestic` Galaxy role |
| `roles/msmtp/` | msmtp role wrapping `chriswayg.msmtp-mailer` Galaxy role |
| `roles/defaults/main.yml` | Stray defaults file: `run_msmtp_mailer`, `hardening_enabled` |
| `ansible.cfg` | Basic config — no vault_identity_list, uses `inventories/production` |

## Target State (per REQUIREMENTS.md §2)

```
ansible/
├── ansible.cfg           (updated)
├── Makefile
├── requirements.yml
├── .ansible-lint
├── README.md
├── TROUBLESHOOTING.md
├── inventories/prod/ + test/
├── playbooks/
├── roles/common/         (migrated + split + tagged)
├── roles/dnsmasq/        (stub)
├── roles/docker/         (stub)
├── roles/caddy/          (stub)
├── roles/compose_stack/  (fully implemented)
├── stacks/{paperless-ngx,beszel,sist2,gatus}/
└── templates/
```

## Migration Mapping (existing → target)

| Existing | → Target |
|---|---|
| `common/tasks/users-authentication.yml` | `roles/common/tasks/users.yml` (tags: common, bootstrap, users) |
| `common/tasks/hardening.yml` | `roles/common/tasks/host_security.yml` (tags: common, host_security) |
| New file | `roles/common/tasks/ssh.yml` (tags: common, bootstrap, ssh) |
| New file | `roles/common/tasks/firewall.yml` (tags: common, bootstrap, firewall) |
| `common/tasks/packages.yml` | `roles/common/tasks/packages.yml` (tags: common, packages) |
| `common/tasks/unattended-upgrades.yml` | `roles/common/tasks/updates.yml` + `auto_security.yml` |
| `roles/msmtp/` | `roles/common/tasks/msmtp.yml` (tags: common, msmtp) |
| `roles/autorestic/` | `roles/common/tasks/backup.yml` (tags: common, backup) |
| `deploy-scripts/` | `roles/common/tasks/scripts.yml` + `roles/common/files/bin/` |
| `common/templates/` | `roles/common/templates/` |
| `common/files/` | `roles/common/files/` |
| `common/vars/main.yml` + `roles/defaults/main.yml` | `roles/common/defaults/main.yml` |
| `common/handlers/main.yml` | `roles/common/handlers/main.yml` |

## Step-by-Step Plan

### Step 1 — Scaffold the directory skeleton
Create all new directories and top-level config files. No existing files are deleted yet.

Files to create:
- `Makefile` (§5)
- `requirements.yml` (§6)
- `.ansible-lint` (§7)
- Updated `ansible.cfg` (§4.4 — add vault_identity_list)
- `inventories/prod/hosts.yml` + `inventories/test/hosts.yml` (§3.6)
- `inventories/prod/group_vars/all/vars.yml` + `vault.yml` placeholder
- `inventories/prod/group_vars/docker_hosts/vars.yml` + `vault.yml`
- `inventories/prod/group_vars/prod/vars.yml` + `vault.yml`
- `inventories/prod/host_vars/{fileserver,saturn,p-docker01}/vars.yml` + `bootstrap.yml` (+ vault where needed)
- `inventories/test/group_vars/all/vars.yml`
- `inventories/test/group_vars/test/vars.yml` + `vault.yml`
- `inventories/test/host_vars/t-docker01/vars.yml` + `bootstrap.yml` + `vault.yml`
- `playbooks/{site,bootstrap,common,docker_hosts,stacks}.yml` (§3.7, §3.8)
- `roles/dnsmasq/tasks/main.yml` (stub)
- `roles/docker/tasks/main.yml` (stub)
- `roles/caddy/{tasks/main.yml, handlers/main.yml, templates/Caddyfile.j2}` (stub + §3.4)
- `roles/compose_stack/{defaults/main.yml, tasks/main.yml, handlers/main.yml}` (§3.3)
- `stacks/{paperless-ngx,beszel,sist2,gatus}/{docker-compose.yml.j2,env.j2,caddy.j2}`
- `templates/{host_vars.yml.j2,bootstrap.yml.j2}`
- `README.md` (§5 table + new-host walkthrough)
- `TROUBLESHOOTING.md` (§9)

### Step 2 — Migrate and restructure `roles/common/`
The most complex migration. Creates `roles/common/` with all 10 sub-task files using
`import_tasks` (not `include_tasks`) with proper tags including the bootstrap cross-cut.

Sub-tasks and their source:
| Sub-task file | Source | Bootstrap? |
|---|---|---|
| `users.yml` | `common/tasks/users-authentication.yml` | Yes |
| `ssh.yml` | new (harden SSH port, disable root login) | Yes |
| `firewall.yml` | new (UFW rules) | Yes |
| `packages.yml` | `common/tasks/packages.yml` | No |
| `updates.yml` | `common/tasks/unattended-upgrades.yml` | No |
| `auto_security.yml` | new (unattended-security-upgrades config) | No |
| `msmtp.yml` | `roles/msmtp/tasks/main.yml` | No |
| `backup.yml` | `roles/autorestic/tasks/main.yml` | No |
| `host_security.yml` | `common/tasks/hardening.yml` (fail2ban etc.) | No |
| `scripts.yml` | `deploy-scripts/tasks/main.yml` | No |

Also migrate:
- `common/templates/jail_sshd.local.j2` → `roles/common/templates/`
- `common/files/etc/` → `roles/common/files/`
- `roles/autorestic/files/scripts/` → `roles/common/files/bin/`
- `deploy-scripts/files/scripts/` → `roles/common/files/bin/`
- `roles/autorestic/templates/` → `roles/common/templates/`
- Merge `common/vars/main.yml` + `roles/defaults/main.yml` → `roles/common/defaults/main.yml`
- `common/handlers/main.yml` → `roles/common/handlers/main.yml`

### Step 3 — Validate structure
- `make syntax` (ansible-playbook --syntax-check on site.yml)
- `make lint` (ansible-lint)

## Status

- [x] Step 1: Scaffold directory skeleton
- [x] Step 2: Migrate roles/common/
- [x] Step 3: Validate with lint + syntax check
- [x] Step 4: Bootstrap bp-testdeployment successfully (packages-first ordering, cron fix, autorestic guard)
