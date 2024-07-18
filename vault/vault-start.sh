PROJECT_DIR=~/vault-admin-policies/vault

export PATH=~/bin-vault-ent-1.17.2:$PATH
export VAULT_LICENSE_PATH=~/bin-vault-ent-1.17.2/vault.hclic

export DBUS_SESSION_BUS_ADDRESS=/dev/null
nohup vault server -config $PROJECT_DIR/config.hcl > $PROJECT_DIR/vault_$(date +%Y%m%d_%H%M%S).log 2>&1 <&- &
