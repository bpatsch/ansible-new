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
# `make backup`        -> site.yml --tags backup
# `make paperless-ngx` -> site.yml --tags paperless-ngx
%:
	@if [ -f playbooks/$@.yml ]; then \
	    $(PLAYBOOK) playbooks/$@.yml $(LIMIT); \
	else \
	    $(PLAYBOOK) playbooks/site.yml --tags $@ $(LIMIT); \
	fi
