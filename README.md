# Ansible Fleet Management

Manages a small Linux fleet including hosts that run Docker Compose stacks behind Caddy.

## Quick reference

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

## First time on a new host

### 1. Scaffold and configure

```bash
make scaffold-hosts HOST=newhost ENV=prod
```

Then edit the two generated files:

**`inventories/prod/host_vars/newhost/vars.yml`** — steady-state connection profile:
```yaml
ansible_host: 1.2.3.4        # IP (needed until DNS is set up)
ansible_user: ansible         # must match admin_user (see below)
ansible_port: 2222            # hardened SSH port; set to 22 to keep default
ansible_become: true
ssh_port: 2222                # port sshd will be configured to listen on
```

**`inventories/prod/host_vars/newhost/bootstrap.yml`** — initial root connection:
```yaml
ansible_user: root
ansible_port: 22
ansible_become: false
```

Add the host to `inventories/prod/hosts.yml` under `docker_hosts` or `plain_hosts` (and `prod`).

### 2. The admin user

`admin_user` (default: `ansible`, set in `group_vars/all/vars.yml`) is the non-root user
that bootstrap creates and all subsequent runs connect as.

Bootstrap (`roles/common/tasks/users.yml`) does three things:
- Creates the `admin_user` account in the `sudo` group
- Grants passwordless sudo to the `sudo` group
- Adds the control host's `~/.ssh/id_rsa.pub` as an authorized key

After bootstrap, `ansible_user` in `vars.yml` must match `admin_user` so steady-state
runs connect as the right user.

**If the server already has a pre-existing user** (e.g. `bpatsch` was created by the
cloud provider), set `admin_user` in that host's `vars.yml` to match:
```yaml
admin_user: bpatsch
ansible_user: bpatsch
```
Bootstrap will then configure that existing user (add it to sudo, add the SSH key)
instead of creating a new one.

### 3. Bootstrap and steady state

```bash
# Bootstrap: runs as the user in bootstrap.yml, applies users/ssh/firewall only
make first-run HOST=newhost

# Steady-state: runs as admin_user on the hardened port, applies everything
make run HOST=newhost
```

## Vault setup

Vault passwords are provided via `scripts/vault-secret-client.sh`, which reads
environment variables:

```bash
export VAULT_PASS_PROD="your-prod-password"
export VAULT_PASS_TEST="your-test-password"
```

Encrypt a vault file for the prod environment:

```bash
make vault-create FILE=inventories/prod/group_vars/all/vault.yml ENV=prod
```

## Adding a new stack

1. Create `stacks/<stack>/{docker-compose.yml.j2,env.j2,caddy.j2}`
2. Add `<stack>` to the `stacks:` list in the target host's `host_vars/<host>/vars.yml`
3. Add any secrets to that host's `vault.yml` and alias in `vars.yml`
4. Deploy: `make <stack> HOST=<host>`

## Installing Galaxy dependencies

```bash
make requirements
```
