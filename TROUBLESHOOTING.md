# Troubleshooting

## Locale error: "Ansible requires the locale encoding to be UTF-8"

Fix:
```bash
export LC_ALL=en_US.UTF-8
```
Or pick another UTF-8 locale from `locale -a`.

## "Failed to connect to the host via ssh" on a fresh host

You probably skipped `make first-run HOST=<name>`. The steady-state `vars.yml` assumes the hardened SSH profile (non-root user, custom port); a fresh host still uses the root profile from `bootstrap.yml`. Run `make first-run HOST=<name>` first.

## "undefined variable" for some `*_password`

The vault is not being decrypted. Check that:
- `~/.ansible/vault-prod` and/or `~/.ansible/vault-test` exist and contain the correct key
- The labeled vault id in the encrypted file matches `ENV` (prod vs test)
- You are running against the right inventory (`ENV=prod` vs `ENV=test`)

## "Unable to encrypt nor hash, passlib must be installed"

```bash
pip install passlib
```

Run on the control host (the machine running Ansible).

## YAML / Jinja errors

```bash
make syntax   # ansible-playbook --syntax-check
make lint     # ansible-lint
```

## Module not found, e.g. `community.docker.docker_compose_v2`

```bash
make requirements
```

Confirm `ansible.cfg` has a `roles_path` or `collections_paths` resolvable from the repo root.

## Stack templates not found

`compose_stack` reads from `stacks/<stack_name>/`. Check that:
- The directory `stacks/<stack_name>/` exists
- All three `.j2` files are present: `docker-compose.yml.j2`, `env.j2`, `caddy.j2`
- The stack name in `host_vars/<host>/vars.yml` matches the directory name exactly (case-sensitive)

## SSH port changed but Ansible still tries port 22

After `make first-run`, steady-state uses the port in `host_vars/<host>/vars.yml` (`ansible_port`). If you ran first-run but did not update `vars.yml`, fix `ansible_port` there.

## Caddy not picking up a new stack snippet

Verify the snippet landed in `/etc/caddy/sites/<stack>.caddy` on the host, then:
```bash
make caddy HOST=<host>
```
This re-runs the caddy role and reloads the service.
