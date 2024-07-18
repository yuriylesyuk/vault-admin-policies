
# Separation of Duties for admins and developer for secrets engines access

```
[x] policies by roles
[ ] role escalation
   [ ] token minting?
   [ ] login as different user?
   [ ] ldap groups?
   [ ] alerts on audit logs

[ ] control groups approvals

[ ] Sentinel (rgp, egp): 
```

## Install Vault

For some features we need ent version of vault. In this case, we use PATH to binary and the license file variable

```sh
mkdir -p ~/bin-vault-ent-1.17.2
cd bin-vault-ent-1.17.2

curl -LO https://releases.hashicorp.com/vault/1.17.2+ent/vault_1.17.2+ent_linux_amd64.zip

unzip vault_1.17.2+ent_linux_amd64.zip
```

Copy .hclic file to ~/bin-vault-ent-1.17.2
```
cat <<"EOF" >vault-start.sh
PROJECT_DIR=~/vault-admin-policies/vault

export PATH=~/bin-vault-ent-1.17.2:$PATH
export VAULT_LICENSE_PATH=~/bin-vault-ent-1.17.2/vault.hclic

export DBUS_SESSION_BUS_ADDRESS=/dev/null
nohup vault server -config $PROJECT_DIR/config.hcl > vault_$(date +%Y%m%d_%H%M%S).log 2>&1 <&- &
EOF
```





## Provision Vault
```
PROJECT_DIR=~/vault-admin-policies/vault
cd
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/data
cd $PROJECT_DIR
```


cat <<EOF > $PROJECT_DIR/config.hcl
cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://127.0.0.1:8200"


storage "raft" {
   path    = "$PROJECT_DIR/data"
   node_id = "vault_1"
}

listener "tcp" {
   address = "0.0.0.0:8200"
   cluster_address = "127.0.0.1:8201"
   tls_disable = true
}

ui = true
disable_mlock = true
EOF


```
export DBUS_SESSION_BUS_ADDRESS=/dev/null
nohup vault server -config $PROJECT_DIR/config.hcl > vault_$(date +%Y%m%d_%H%M%S).log 2>&1 <&- &

export VAULT_ADDR=http://127.0.0.1:8200
```

## ~/.bashrc
```sh
export VAULT_ADDR=http://127.0.0.1:8200

complete -C /home/ec2-user/bin/vault vault

complete -C /usr/bin/terraform terraform
```

```
vault status
```


```
vault operator init -key-shares=1 -key-threshold=1 > vault-init.txt
```

```
vault operator unseal $(awk '/Unseal Key 1:/{print $4}' vault-init.txt)
```

```
vault login $(awk '/Root Token:/{print $4}' vault-init.txt); export VAULT_TOKEN=$(cat ~/.vault-token)
```

## Install terraform Amazon Linux

https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

```
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

sudo yum -y install terraform
```

```
terraform version

Terraform v1.9.2
on linux_amd64
```


## Vault admin policies: CLI edition

```
vault auth enable userpass

vault write auth/userpass/users/admin \
    password=foo \
    policies=admin_secrets_policy

vault write auth/userpass/users/dev \
    password=foo \
    policies=developer_secrets_policy

vault write auth/userpass/users/cicd \
    password=foo \
    policies=cicd_secrets_policy








# Map users to their groups
vault write identity/group-alias name="admin_alias" \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') \
    canonical_id=$(vault read -field=id identity/group/name/admins)

vault write identity/group-alias name="dev_alias" \
    canonical_id=$(vault read -field=id identity/entity/name/dev_user) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') \
    group_id=$(vault read -field=id identity/group/name/developers)
```

## Workflow: Admin creates and Manages Secret Engines

-output-policy

```sh
export VAULT_TOKEN=

vault token lookup
```

```sh
# Admin: enabling a new KV secret engine

vault login -method=userpass \
    username=admin \
    password=foo


vault secrets enable -path=secret kv
```


## Setup policy development session:

1. start Vault server

1. Open bash terminals:

    * super-admin: root, export VAULT_TOKEN=
    * admin: admi, export VAULT_TOKEN=
    * dev: dev, ~/.vault-token
    * cicd: cicd, ~/.vault-token


When/if we are using a same Linux user terminals, ~/.vault-token gets overrriden by the last login command. The workaround is to consistenty use `vault login <>; ;    export VAULT_TOKEN=$(cat ~/.vault-token)` to guarantee that the last .vault-token is in the current shell env variable.

1. Validation table:

| Op                                                                 | Admin   | Dev     | Cicd    | Terraform |
|---|:---:|:---:|:---:|:---:|
| vault secrets enable -path=secret kv                               | &check; | &cross; | &cross; |
| vault secrets disable secret                                       | &check; | &cross; | &cross; |
| vault kv list secret                                               | &cross; | &check; | &check; |
| vault kv get secret/creds                                          | &cross; | &check; | &check; |
| vault kv put -mount=secret creds db-user="user" password="db-pass" | &cross; | &check; | &cross; |
| vault kv get -mount=secret -field=db-user creds                    | &cross; | &check; | &check; |


## Developer: Accesses Secrets

```sh
vault secret -output-policy disable

vault token create -policy=developer_secrets_policy -period=30m


# Developer writing a secret
vault login -method=userpass username=admin password=foo;   export VAULT_TOKEN=$(cat ~/.vault-token)
vault login -method=userpass username=dev password=foo;     export VAULT_TOKEN=$(cat ~/.vault-token)
vault login -method=userpass username=cicd password=foo;    export VAULT_TOKEN=$(cat ~/.vault-token)


vault kv put -output-policy -mount=secret creds username="user" password="password"
vault kv put -mount=secret creds username="user" password="password"

vault kv get -output-policy -mount=secret -field=password creds
vault kv get -mount=secret -field=password creds

vault kv get -field=username secret/creds 
vault kv list secret
vault kv get secret/creds

vault kv put -mount=secret creds db-user="user" password="db-pass"
vault kv get -mount=secret -field=db-user creds

# Developer reading a secret
vault kv get secret/myapp/config
```

Add policy option to only read keys / parameters of secrets 
https://github.com/hashicorp/vault/issues/10704


```
vault read -format=json sys/internal/ui/mounts|jq 
```

## Debugging: Active ACL:

https://developer.hashicorp.com/vault/api-docs/system/internal-ui-resultant-acl

```
vault read -format=json sys/internal/ui/resultant-acl
```


## Control Groups for escalating ability to access secret contents with developer's authorization 

https://developer.hashicorp.com/vault/tutorials/enterprise/control-groups

* requires Identity Groups as factor

[ ] in the admin_secrets_policy.hcl, instead of deny:

```
# Create superadmin group
vault write identity/group name="admins" policies="admin_secrets_policy"

vault write identity/group name="superadmins" policies="superadmin_secrets_policy"

# Create developer group
vault write identity/group name="developers" policies="developers_authorizers_policy"


# Add users to their respective groups (example for admin_user and dev_user)
vault write identity/entity name="superadmin"
vault write identity/entity name="dev"

vault write identity/group name="superadmins" \
    member_entity_ids=$(vault read -field=id identity/entity/name/superadmin)

vault write identity/group name="developers" \
    member_entity_ids=$(vault read -field=id identity/entity/name/dev)


# Map users to their groups
vault write identity/entity-alias \
    name="superadmin" \
    canonical_id=$(vault read -field=id identity/entity/name/superadmin) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') 

vault write identity/entity-alias \
    name="dev" \
    canonical_id=$(vault read -field=id identity/entity/name/dev) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') 


# check the config
vault read identity/group/name/superadmins

vault read identity/group/name/developers
```


```
vault write auth/userpass/users/superadmin password=foo

vault login -method=userpass username=superadmin password=foo;    export VAULT_TOKEN=$(cat ~/.vault-token)
```




```
path "secret/*" {
    capabilities = ["write","read","list"]
    control_group = {
        ttl = "1h"        
        factor "authorizer-dev" {
            identity {
                group_names = ["developers"]
                approvals = 1
            }
        }
    }
}
```

vault read -format=json sys/internal/ui/resultant-acl

# superadmin: 
vault kv get secret/creds

vault kv get -field=username secret/creds

vault unwrap $WRAPPING_TOKEN


# dev:
export WRAPPING_ACCESSOR=
vault write sys/control-group/request accessor=$WRAPPING_ACCESSOR

vault write sys/control-group/authorize accessor=$WRAPPING_ACCESSOR

# superadmin: 
export WRAPPING_TOKEN=
vault unwrap $WRAPPING_TOKEN



[ ] check audit
[ ] raise alert??