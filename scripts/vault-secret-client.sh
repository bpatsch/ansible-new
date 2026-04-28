#!/bin/bash
# Ansible vault-id client script.
# Ansible calls this with --vault-id <label> when the script name ends in "-client".
# Export VAULT_PASS_PROD and VAULT_PASS_TEST before running ansible commands,
# or VAULT_PASS as a fallback for any label.

vault_id=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault-id)
            vault_id="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

case "$vault_id" in
    prod)
        echo "${VAULT_PASS_PROD:-${VAULT_PASS}}"
        ;;
    test)
        echo "${VAULT_PASS_TEST:-${VAULT_PASS}}"
        ;;
    *)
        echo "${VAULT_PASS}"
        ;;
esac
