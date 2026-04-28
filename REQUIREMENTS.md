# Ansible Project Structure — Specification

This document specifies the structure for an Ansible repository that manages a small fleet of Linux hosts, including some that run Docker Compose stacks behind Caddy. The design follows the KISS principle while leaving clean extension points for new stacks, new hosts, and new environments.

This file is intended as a hand-off spec for a coding agent (e.g. claude-cli). It is descriptive and prescriptive: follow the structure, naming conventions, and rules below.

---

## 1. Scope

The Ansible repo must manage:

### Common concerns (every host)
- Package installation (with shared base list + per-host/group extras)
- Package updates
- Automatic security updates
- `msmtp` setup
- `restic` + `autorestic` backup
- Host security hardening
- Deployment of scripts to `/usr/local/bin`

### Optional concerns (subset of hosts)
- `dnsmasq`
- Docker engine + Docker Compose plugin
- Caddy reverse proxy (one instance **per host** that runs stacks)
- Docker Compose stacks, all sharing the same on-disk structure:
  - Compose files in `/var/data/config/<stack-name>/`
  - Stack data in `/var/data/containers/<stack-name>/`
  - A Caddy snippet per stack on the host that runs it
- Initial set of stacks: `paperless-ngx`, `beszel`, `sist2`, `gatus`

### Hosts (initial)
- `fileserver` — common only
- `saturn` — common + docker + some stacks (e.g. `gatus`)
- `p-docker01` — common + docker + some stacks (PRODUCTION)
- `t-docker01` — common + docker + some stacks (TEST)

### Lifecycle: bootstrap vs steady state

A fresh host is reachable only as `root` on the default SSH port. The `common` role hardens this:
creates a non-root user, disables root SSH login, may change the SSH port, enables UFW.
After that, the connection parameters used to reach the host change.

This means there are **two distinct run modes**:
1. **Bootstrap (`make first-run`)** — connects as `root` on port 22, runs the minimum
   required (users, ssh, firewall) to flip the host into steady state.
2. **Steady state (`make run`)** — connects as the unprivileged user on the hardened
   SSH port, runs everything else.

The repo must support both without duplicated inventories.

---

## 2. Directory layout

Create exactly this structure:

```
ansible/
├── ansible.cfg
├── Makefile
├── requirements.yml                # Galaxy collections/roles, version-pinned
├── .ansible-lint                   # ansible-lint config
├── README.md
├── TROUBLESHOOTING.md
│
├── inventories/
│   ├── prod/
│   │   ├── hosts.yml
│   │   ├── group_vars/
│   │   │   ├── all/
│   │   │   │   ├── vars.yml
│   │   │   │   └── vault.yml       # encrypted
│   │   │   ├── docker_hosts/
│   │   │   │   ├── vars.yml
│   │   │   │   └── vault.yml       # encrypted
│   │   │   └── prod/
│   │   │       ├── vars.yml
│   │   │       └── vault.yml       # encrypted
│   │   └── host_vars/
│   │       ├── fileserver/
│   │       │   ├── vars.yml
│   │       │   └── bootstrap.yml   # connection vars used only by first-run
│   │       ├── saturn/
│   │       │   ├── vars.yml
│   │       │   ├── bootstrap.yml
│   │       │   └── vault.yml       # only if needed
│   │       └── p-docker01/
│   │           ├── vars.yml
│   │           ├── bootstrap.yml
│   │           └── vault.yml
│   └── test/
│       ├── hosts.yml
│       ├── group_vars/
│       │   ├── all/
│       │   │   └── vars.yml
│       │   └── test/
│       │       ├── vars.yml
│       │       └── vault.yml
│       └── host_vars/
│           └── t-docker01/
│               ├── vars.yml
│               ├── bootstrap.yml
│               └── vault.yml
│
├── playbooks/
│   ├── site.yml                    # steady-state entrypoint, imports the rest
│   ├── bootstrap.yml               # first-run, minimal hardening as root
│   ├── common.yml                  # only the common role
│   ├── docker_hosts.yml            # docker engine + caddy + stacks
│   └── stacks.yml                  # only (re)deploy stacks
│
├── roles/
│   ├── common/
│   │   ├── defaults/main.yml
│   │   ├── handlers/main.yml
│   │   ├── files/bin/              # scripts deployed to /usr/local/bin
│   │   ├── templates/
│   │   └── tasks/
│   │       ├── main.yml            # imports each sub-file with a tag
│   │       ├── users.yml           # used by bootstrap AND steady-state
│   │       ├── ssh.yml             # used by bootstrap AND steady-state
│   │       ├── firewall.yml        # used by bootstrap AND steady-state
│   │       ├── packages.yml
│   │       ├── updates.yml
│   │       ├── auto_security.yml
│   │       ├── msmtp.yml
│   │       ├── backup.yml          # restic + autorestic
│   │       ├── host_security.yml
│   │       └── scripts.yml
│   │
│   ├── dnsmasq/
│   ├── docker/
│   ├── caddy/
│   └── compose_stack/              # ONE generic role, parameterised by stack name
│       ├── defaults/main.yml
│       ├── tasks/main.yml
│       └── handlers/main.yml
│
├── stacks/                         # per-stack content (data, not code)
│   ├── paperless-ngx/
│   │   ├── docker-compose.yml.j2
│   │   ├── env.j2
│   │   └── caddy.j2
│   ├── beszel/
│   │   ├── docker-compose.yml.j2
│   │   ├── env.j2
│   │   └── caddy.j2
│   ├── sist2/
│   │   ├── docker-compose.yml.j2
│   │   ├── env.j2
│   │   └── caddy.j2
│   └── gatus/
│       ├── docker-compose.yml.j2
│       ├── env.j2
│       └── caddy.j2
│
└── templates/                      # repo-level templates (used by `make scaffold-hosts`)
    ├── host_vars.yml.j2
    └── bootstrap.yml.j2
```

---

## 3. Design rules

### 3.1 `common` is one role with tagged sub-tasks

Do **not** split `common` into multiple roles. `roles/common/tasks/main.yml` imports each sub-file with a tag:

```yaml
- import_tasks: users.yml
  tags: [common, bootstrap, users]
- import_tasks: ssh.yml
  tags: [common, bootstrap, ssh]
- import_tasks: firewall.yml
  tags: [common, bootstrap, firewall]
- import_tasks: packages.yml
  tags: [common, packages]
- import_tasks: updates.yml
  tags: [common, updates]
- import_tasks: auto_security.yml
  tags: [common, auto_security]
- import_tasks: msmtp.yml
  tags: [common, msmtp]
- import_tasks: backup.yml
  tags: [common, backup]
- import_tasks: host_security.yml
  tags: [common, host_security]
- import_tasks: scripts.yml
  tags: [common, scripts]
```

The `bootstrap` tag is the cross-cut that selects exactly the sub-tasks safe and necessary
to run as root on a fresh host. `playbooks/bootstrap.yml` invokes `common` with `--tags bootstrap`.

Running `--tags common` runs everything; `--tags backup` runs only that sub-task; `--skip-tags scripts` opts out of one piece.

### 3.2 Package lists layer through vars

In `group_vars/all/vars.yml`:

```yaml
common_packages:
  - vim
  - htop
  - curl
  - rsync
  # …
```

Per group or host, define `extra_packages` (a list). The `packages.yml` task installs the union:

```yaml
- name: Install base + extra packages
  ansible.builtin.package:
    name: "{{ common_packages + (extra_packages | default([])) }}"
    state: present
```

### 3.3 One generic `compose_stack` role

There is **one** role for all stacks. It is parameterised by `stack_name` and reads templates from `stacks/<stack_name>/`.

`roles/compose_stack/tasks/main.yml` (reference implementation):

```yaml
- name: Create stack directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - "/var/data/config/{{ stack_name }}"
    - "/var/data/containers/{{ stack_name }}"

- name: Render compose file
  ansible.builtin.template:
    src: "{{ playbook_dir }}/../stacks/{{ stack_name }}/docker-compose.yml.j2"
    dest: "/var/data/config/{{ stack_name }}/docker-compose.yml"
    mode: "0644"
  notify: "restart {{ stack_name }}"

- name: Render env file
  ansible.builtin.template:
    src: "{{ playbook_dir }}/../stacks/{{ stack_name }}/env.j2"
    dest: "/var/data/config/{{ stack_name }}/.env"
    mode: "0600"
  notify: "restart {{ stack_name }}"

- name: Drop caddy snippet for stack
  ansible.builtin.template:
    src: "{{ playbook_dir }}/../stacks/{{ stack_name }}/caddy.j2"
    dest: "/etc/caddy/sites/{{ stack_name }}.caddy"
    mode: "0644"
  notify: reload caddy

- name: Bring stack up
  community.docker.docker_compose_v2:
    project_src: "/var/data/config/{{ stack_name }}"
    state: present
```

Adding a new stack must require:
- creating `stacks/<new-stack>/{docker-compose.yml.j2, env.j2, caddy.j2}`
- adding the stack name to a host's `stacks:` list

No new role and no playbook changes.

### 3.4 Caddy: one shared instance per host, per-stack snippets

The `caddy` role installs Caddy and writes a top-level `Caddyfile` containing:

```
import /etc/caddy/sites/*.caddy
```

Each stack drops its own snippet into `/etc/caddy/sites/<stack_name>.caddy` (handled by the `compose_stack` role, see 3.3). Adding/removing a stack therefore wires/unwires the reverse proxy automatically.

### 3.5 Stack assignment lives in `host_vars`

Example `inventories/prod/host_vars/p-docker01/vars.yml`:

```yaml
stacks:
  - paperless-ngx
  - sist2
  - gatus

paperless_ngx:
  domain: paperless.prod.example.com
  admin_email: ops@example.com

gatus:
  domain: status.prod.example.com
```

`playbooks/docker_hosts.yml` then loops:

```yaml
- hosts: docker_hosts
  roles:
    - common
    - docker
    - caddy
  tasks:
    - name: Deploy stacks declared on this host
      ansible.builtin.include_role:
        name: compose_stack
      vars:
        stack_name: "{{ item }}"
      loop: "{{ stacks | default([]) }}"
      tags: ["{{ item }}", stacks]
```

### 3.6 Inventory groups

`inventories/prod/hosts.yml`:

```yaml
all:
  children:
    docker_hosts:
      hosts:
        saturn:
        p-docker01:
    plain_hosts:
      hosts:
        fileserver:
    prod:
      hosts:
        saturn:
        p-docker01:
        fileserver:
```

`inventories/test/hosts.yml`:

```yaml
all:
  children:
    docker_hosts:
      hosts:
        t-docker01:
    test:
      hosts:
        t-docker01:
```

The same playbooks run against either inventory; only `-i inventories/<env>` changes.

### 3.7 `site.yml` is the steady-state entrypoint

```yaml
- import_playbook: common.yml
- import_playbook: docker_hosts.yml
```

`playbooks/common.yml`:

```yaml
- hosts: all
  roles:
    - common
```

`playbooks/docker_hosts.yml`: as in 3.5.

`playbooks/stacks.yml`: same as `docker_hosts.yml` but skips `common`/`docker`/`caddy`
(intended use: `make stacks HOST=p-docker01`).

### 3.8 Bootstrap playbook (first run on a fresh host)

`playbooks/bootstrap.yml` exists to flip a fresh host (root + port 22 + no firewall) into
its steady-state configuration. It runs only the cross-cut `bootstrap` tag of `common`:

```yaml
- hosts: "{{ target | default('all') }}"
  gather_facts: true
  roles:
    - role: common
      tags: [bootstrap]
```

Connection vars come from a per-host `bootstrap.yml` passed via `--extra-vars`, so the
normal `vars.yml` (which describes the *post-bootstrap* connection) stays untouched.

Example `inventories/prod/host_vars/p-docker01/bootstrap.yml`:

```yaml
ansible_user: root
ansible_port: 22
ansible_become: false
```

Example `inventories/prod/host_vars/p-docker01/vars.yml`:

```yaml
ansible_user: ansible
ansible_port: 2222
ansible_become: true
```

The Makefile target `first-run` wires this together (see section 5).

---

## 4. Vault and secrets

### 4.1 File location

Vault files live **next to** the plain vars they belong to, never in a separate top-level directory. This requires turning each `group_vars`/`host_vars` entry into a **directory** containing `vars.yml` and (optionally) `vault.yml`. Ansible auto-loads every file in those directories and merges them into the same scope.

Only create a `vault.yml` where there are actually secrets for that scope. A host with no unique secrets needs only `vars.yml`.

### 4.2 Naming convention

Inside `vault.yml`, prefix every variable with `vault_`. Never reference `vault_*` directly from roles, templates, or playbooks. Instead, alias them in the sibling `vars.yml`:

```yaml
# group_vars/all/vault.yml  (encrypted)
vault_msmtp_password: "s3cret"
vault_restic_repo_password: "anothers3cret"
```

```yaml
# group_vars/all/vars.yml   (plain)
msmtp_password: "{{ vault_msmtp_password }}"
restic_repo_password: "{{ vault_restic_repo_password }}"
```

Rules:
- `grep -r vault_ roles/` must always return empty.
- Roles and templates only ever see "normal" variable names.
- The aliasing line in `vars.yml` is the single place where secrets enter the namespace.

### 4.3 Per-stack secrets

Secrets for a specific stack go in the `host_vars` vault of the host that runs it:

```yaml
# host_vars/p-docker01/vault.yml  (encrypted)
vault_paperless_admin_password: "…"
vault_gatus_oidc_client_secret: "…"
```

```yaml
# host_vars/p-docker01/vars.yml
paperless_ngx:
  domain: paperless.prod.example.com
  admin_password: "{{ vault_paperless_admin_password }}"
```

The Jinja templates in `stacks/paperless-ngx/env.j2` reference only `paperless_ngx.admin_password` — they remain oblivious to the vault.

### 4.4 Separate vault passwords per environment

Use a labeled vault id per environment so a leaked test password cannot decrypt prod. In `ansible.cfg`:

```ini
[defaults]
inventory = inventories/prod
roles_path = roles
host_key_checking = False

vault_identity_list = prod@~/.ansible/vault-prod, test@~/.ansible/vault-test
```

When creating or rekeying a vault file, label it:

```bash
ansible-vault encrypt --encrypt-vault-id prod \
  inventories/prod/group_vars/all/vault.yml

ansible-vault encrypt --encrypt-vault-id test \
  inventories/test/group_vars/test/vault.yml
```

Ansible then picks the correct key automatically based on the label embedded in each file.

### 4.5 Anti-patterns to avoid

- ❌ A top-level `secrets/` or `vault/` directory parallel to `inventories/`. Detaches secrets from scope and forces extra `vars_files:` plumbing.
- ❌ A single repo-root `vault.yml` for "all secrets." Forces every run to decrypt everything; defeats prod/test isolation.
- ❌ Committing a `.vault_pass` file (even gitignored). Keep password files outside the repo (`~/.ansible/…`) or fetch them from a password manager via a script referenced by `vault_password_file`.
- ❌ Referencing `vault_*` variables directly from roles. Always alias in `vars.yml` first.

---

## 5. Makefile (operator UX)

The `Makefile` is the primary entry point for humans. It hides the `-i inventories/<env>`
flag behind an `ENV` variable that defaults to `prod`, and provides both fixed and
dynamic targets.

```makefile
# ============================================================================
# Ansible operator UX
# ============================================================================

ENV       ?= prod
HOST      ?=
INVENTORY := inventories/$(ENV)
PLAYBOOK  := ansible-playbook -i $(INVENTORY)

# Optional limit fragment: only added when HOST is set
LIMIT     := $(if $(HOST),--limit $(HOST),)

.PHONY: help ping run first-run bootstrap stacks lint syntax check \
        scaffold-hosts requirements vault-edit vault-create

# ---- Help (default target) -------------------------------------------------
help:
	@echo "Usage: make <target> [ENV=prod|test] [HOST=<name>]"
	@echo ""
	@echo "Lifecycle:"
	@echo "  first-run HOST=<name>   Bootstrap a fresh host (connect as root)"
	@echo "  run                     Steady-state run of site.yml against \$$ENV"
	@echo "  ping                    Connectivity test against \$$ENV"
	@echo ""
	@echo "Targeted runs:"
	@echo "  stacks HOST=<name>      (Re)deploy compose stacks on one host"
	@echo "  <playbook>              Run playbooks/<playbook>.yml"
	@echo "  <role-or-tag>           Run site.yml limited to that tag"
	@echo ""
	@echo "Repo maintenance:"
	@echo "  requirements            Install pinned Galaxy collections/roles"
	@echo "  scaffold-hosts HOST=... Generate inventory stubs for a new host"
	@echo "  lint                    Run ansible-lint"
	@echo "  syntax                  ansible-playbook --syntax-check on site.yml"
	@echo "  check                   Dry run with --check --diff"
	@echo ""
	@echo "Vault:"
	@echo "  vault-create FILE=...   Create a new vault file"
	@echo "  vault-edit   FILE=...   Edit an existing vault file"

# ---- Lifecycle -------------------------------------------------------------
ping:
	ansible -i $(INVENTORY) all -m ping

run:
	$(PLAYBOOK) playbooks/site.yml $(LIMIT)

# Bootstrap: connect as root on default port, run only the `bootstrap` tag.
# The bootstrap.yml extra-vars file overrides the connection profile.
first-run:
ifndef HOST
	$(error HOST is required: make first-run HOST=<name>)
endif
	$(PLAYBOOK) playbooks/bootstrap.yml \
	    --limit $(HOST) \
	    --extra-vars "@$(INVENTORY)/host_vars/$(HOST)/bootstrap.yml"

bootstrap: first-run

# ---- Targeted runs ---------------------------------------------------------
stacks:
ifndef HOST
	$(error HOST is required: make stacks HOST=<name>)
endif
	$(PLAYBOOK) playbooks/stacks.yml --limit $(HOST)

check:
	$(PLAYBOOK) playbooks/site.yml --check --diff $(LIMIT)

# ---- Repo maintenance ------------------------------------------------------
requirements:
	ansible-galaxy install -r requirements.yml --force

lint:
	ansible-lint

syntax:
	$(PLAYBOOK) playbooks/site.yml --syntax-check

# Scaffold a new host: requires HOST=<name>; creates host_vars/<HOST>/{vars,bootstrap}.yml
scaffold-hosts:
ifndef HOST
	$(error HOST is required: make scaffold-hosts HOST=<name>)
endif
	@mkdir -p $(INVENTORY)/host_vars/$(HOST)
	@cp -n templates/host_vars.yml.j2  $(INVENTORY)/host_vars/$(HOST)/vars.yml
	@cp -n templates/bootstrap.yml.j2  $(INVENTORY)/host_vars/$(HOST)/bootstrap.yml
	@echo "Created $(INVENTORY)/host_vars/$(HOST)/{vars.yml,bootstrap.yml}"
	@echo "Now add '$(HOST):' under the right group in $(INVENTORY)/hosts.yml"

# ---- Vault helpers ---------------------------------------------------------
vault-create:
ifndef FILE
	$(error FILE is required: make vault-create FILE=path/to/vault.yml)
endif
	ansible-vault create --encrypt-vault-id $(ENV) $(FILE)

vault-edit:
ifndef FILE
	$(error FILE is required: make vault-edit FILE=path/to/vault.yml)
endif
	ansible-vault edit $(FILE)

# ---- Catch-all: dispatch to playbook OR tag --------------------------------
# `make backup`        -> site.yml --tags backup        (because roles/common has a `backup` tag)
# `make stacks`        -> playbooks/stacks.yml          (handled above explicitly)
# `make paperless-ngx` -> site.yml --tags paperless-ngx (matches the per-stack tag)
%:
	@if [ -f playbooks/$@.yml ]; then \
	    $(PLAYBOOK) playbooks/$@.yml $(LIMIT); \
	else \
	    $(PLAYBOOK) playbooks/site.yml --tags $@ $(LIMIT); \
	fi
```

### Operator workflows this supports

| Goal | Command |
|---|---|
| Bootstrap a brand-new host | `make first-run HOST=p-docker01` |
| Apply everything to prod | `make run` |
| Apply everything to test | `make run ENV=test` |
| Apply only to one host | `make run HOST=saturn` |
| Redeploy stacks on one host | `make stacks HOST=p-docker01` |
| Redeploy a single stack on a host | `make paperless-ngx HOST=p-docker01` |
| Run only the backup sub-task across the fleet | `make backup` |
| Run only msmtp on test | `make msmtp ENV=test` |
| Dry-run everything | `make check` |
| Connectivity check | `make ping` |
| Add a new host scaffold | `make scaffold-hosts HOST=neptune` |
| Lint the repo | `make lint` |
| Edit a vault file | `make vault-edit FILE=inventories/prod/group_vars/all/vault.yml` |

---

## 6. `requirements.yml` — pin everything

External Galaxy content must be version-pinned. Drift in `community.docker` in particular has
broken the compose API more than once.

```yaml
---
collections:
  - name: community.docker
    version: "3.10.0"
  - name: ansible.posix
    version: "1.5.4"
  - name: community.general
    version: "9.5.0"

# Add roles here only if a Galaxy role genuinely beats writing it ourselves.
# Prefer writing small focused roles in roles/ over wrapping upstream roles.
roles: []
```

Install with `make requirements` (which calls `ansible-galaxy install -r requirements.yml --force`).

---

## 7. `ansible-lint` configuration

Place a `.ansible-lint` at the repo root:

```yaml
---
profile: production

exclude_paths:
  - .cache/
  - .github/
  - inventories/*/group_vars/*/vault.yml
  - inventories/*/host_vars/*/vault.yml

# Tasks must use FQCN (ansible.builtin.*, community.docker.*, etc.)
# Templates in stacks/ are deliberately not under roles/templates — don't flag.
skip_list:
  - role-name           # `compose_stack` is intentionally generic
  - var-naming[no-role-prefix]  # we alias vault_* into role-agnostic vars
```

Run via `make lint`. CI (when added) should run the same target.

---

## 8. Extension recipes

### Add a new stack (e.g. `vaultwarden`)

1. Create `stacks/vaultwarden/docker-compose.yml.j2`, `env.j2`, `caddy.j2`.
2. Add `vaultwarden` to the `stacks:` list of the target host's `host_vars/<host>/vars.yml`.
3. (If secrets) add `vault_vaultwarden_*` to that host's `vault.yml` and alias in `vars.yml`.
4. Deploy: `make vaultwarden HOST=p-docker01`.

No role or playbook changes.

### Add a new host

1. `make scaffold-hosts HOST=neptune` to create the `host_vars/neptune/` skeleton.
2. Fill in `inventories/<env>/host_vars/neptune/vars.yml` (steady-state connection profile + stack list).
3. Fill in `inventories/<env>/host_vars/neptune/bootstrap.yml` (root connection profile).
4. Add `neptune:` under the appropriate group(s) in `inventories/<env>/hosts.yml`.
5. Bootstrap: `make first-run HOST=neptune`.
6. Steady-state: `make run HOST=neptune`.

### Add a new common task (e.g. `chrony`)

1. Add `roles/common/tasks/chrony.yml`.
2. Add an `import_tasks` line with `tags: [common, chrony]` in `roles/common/tasks/main.yml`.
3. `make chrony` runs only the new task across the fleet.

### Promote a stack to a custom role

Only when a stack truly needs logic that does not fit in a Jinja template:
1. Create `roles/stack_<name>/`.
2. Replace the `compose_stack` invocation for that stack with the new role.
3. Leave all other stacks on `compose_stack`.

---

## 9. `TROUBLESHOOTING.md` (prepopulate with these entries)

The repo must include a `TROUBLESHOOTING.md` covering at least:

- **Locale error: "Ansible requires the locale encoding to be UTF-8"**
  Fix: `export LC_ALL=en_US.UTF-8` (or another UTF-8 locale from `locale -a`).
- **"Failed to connect to the host via ssh" on a fresh host**
  You probably skipped `make first-run HOST=<name>`. The steady-state `vars.yml` assumes
  the hardened SSH profile; a fresh host still uses the root profile from `bootstrap.yml`.
- **"undefined variable" for some `*_password`**
  The vault is not being decrypted. Check that `vault_password_file` (or `--ask-vault-pass`)
  is configured, and that the labeled vault id matches the `ENV`.
- **"Unable to encrypt nor hash, passlib must be installed"**
  `pip install passlib` on the control host.
- **YAML / Jinja errors**
  `make syntax` and `make lint`.
- **Module not found, e.g. `community.docker.docker_compose_v2`**
  Run `make requirements`. Confirm `ansible.cfg` has `collections_paths` resolvable.
- **Stack templates not found**
  `compose_stack` reads from `stacks/<stack_name>/`. Check that the directory and the three
  `.j2` files exist and that the stack name in `host_vars` matches the directory name exactly.

---

## 10. Things to deliberately NOT do

- Do **not** split `common` into many roles. The single tag namespace is the point.
- Do **not** create one role per stack up front. `compose_stack` covers all initial stacks.
- Do **not** duplicate playbooks per environment. Inventory selection (`-i inventories/<env>` / `ENV=<env>`) is the env switch.
- Do **not** put a central Caddy config that lists all stacks. Per-stack snippets via `import sites/*.caddy` are self-managing.
- Do **not** centralize secrets. They live next to the vars they parameterize.
- Do **not** write playbooks that assume root SSH. `site.yml` is steady-state only;
  `bootstrap.yml` is the only entry point that may connect as root.
- Do **not** unpin Galaxy collections. `community.docker` in particular is a moving target.

---

## 11. Deliverables checklist

A coding agent implementing this spec should produce:

- [ ] Full directory tree as in section 2
- [ ] `ansible.cfg` with inventory default + `vault_identity_list` for prod and test
- [ ] `requirements.yml` with `community.docker`, `ansible.posix`, `community.general` pinned
- [ ] `.ansible-lint` config as in section 7
- [ ] `Makefile` exactly as in section 5
- [ ] `roles/common/` with all sub-tasks (stub OK), correctly tagged including the `bootstrap` cross-cut on `users`/`ssh`/`firewall`
- [ ] `roles/docker/`, `roles/caddy/`, `roles/dnsmasq/` (stubs OK)
- [ ] `roles/compose_stack/` fully implemented as in section 3.3
- [ ] `stacks/{paperless-ngx,beszel,sist2,gatus}/` each with the three Jinja templates (stub content OK)
- [ ] `playbooks/{site,bootstrap,common,docker_hosts,stacks}.yml`
- [ ] `inventories/{prod,test}/hosts.yml` with the four hosts assigned to the correct groups
- [ ] `group_vars` / `host_vars` directories with `vars.yml`; per-host `bootstrap.yml`; `vault.yml` files created and encrypted with placeholder content
- [ ] `templates/{host_vars.yml.j2,bootstrap.yml.j2}` for `make scaffold-hosts`
- [ ] `README.md` with quickstart (the table from section 5 plus a "first time on a new host" walkthrough)
- [ ] `TROUBLESHOOTING.md` populated with the entries from section 9
- [ ] `make lint` passes
- [ ] `make syntax` passes
- [ ] `make ping` works against a freshly bootstrapped host
