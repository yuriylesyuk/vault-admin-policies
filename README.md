
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

__DDTIP:__ Don't Do This In Production]

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
### DDIP: Login as root token

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

## Audit log in 'debug' mode [DDTIP]:

## Vault admin policies: CLI edition

```
PROJECT_DIR=~/vault-admin-policies/vault

vault audit enable file file_path=$PROJECT_DIR/audit.log log_raw=true
```


## Actors: 

* __Adam Adams__ 
    * __adam__: Administrator; 
    * __aadams__: Super-Administrator
* __Dave Davis__ 
    * __dave__ Developer
* __cicd__: Service Account
* __terraform__: Service Account

```
vault auth enable userpass

vault auth enable -path=userpass-superadmins userpass



vault write auth/userpass/users/adam password=foo
vault write auth/userpass-superadmins/users/aadams password=foo  policies="superadmin_secrets_policy"
vault write auth/userpass/users/dave password=foo
vault write auth/userpass/users/cicd password=foo policies=cicd_secrets_policy


# check:
vault list auth/userpass/users
```


## Control Groups for escalating ability to access secret contents with developer's authorization 

https://developer.hashicorp.com/vault/tutorials/enterprise/control-groups

* requires Identity Groups as factor

```
# checks
vault list identity/entity/name
vault list -detailed identity/entity-alias/id

vault read identity/group/name/admins
vault read identity/group/name/superadmins

# resets
vault delete identity/entity/name/adam-adams
vault delete identity/entity-alias/name/adam

```


```
# Add users to their respective groups (example for admin_user and dev_user)
vault write identity/entity name="adam-adams"


vault write identity/entity-alias \
    name="adam" \
    canonical_id=$(vault read -field=id identity/entity/name/adam-adams) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') 

vault write identity/entity-alias \
    name="aadams" \
    canonical_id=$(vault read -field=id identity/entity/name/adam-adams) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass-superadmins/".accessor') 



vault write identity/entity name="dave-davis"

vault write identity/entity-alias \
    name="dave" \
    canonical_id=$(vault read -field=id identity/entity/name/dave-davis) \
    mount_accessor=$(vault auth list -format=json | jq -r '."userpass/".accessor') 



# Create admin and superadmin groups
vault write identity/group name="admins" policies="admin_secrets_policy"

vault write identity/group name="superadmins"

# Create developer group
vault write identity/group name="developers" policies="developers_authorizers_policy"


# add users to groups
vault write identity/group name="admins" \
    member_entity_ids=$(vault read -field=id identity/entity/name/adam-adams)

vault write identity/group name="superadmins" \
    member_entity_ids=$(vault read -field=id identity/entity/name/adam-adams)

vault write identity/group name="developers" \
    member_entity_ids=$(vault read -field=id identity/entity/name/dave-davis)
```


## check the config
```
vault read identity/group/name/superadmins

vault read identity/group/name/developers
```


## Workflow: Admin creates and Manages Secret Engines

-output-policy

```sh
export VAULT_TOKEN=

vault token lookup
```

```sh
# Admin: enabling a new KV secret engine

vault secrets enable -path=secret kv
```


## Setup policy development session:

1. start Vault server

1. Open bash terminals:

    * aadams, super-admin: root, export VAULT_TOKEN=
    * adam, admin: admi, export VAULT_TOKEN=
    * dave, dev: dev, ~/.vault-token
    * cicd: cicd, ~/.vault-token


When/if we are using a same Linux user terminals, ~/.vault-token gets overrriden by the last login command. The workaround is to consistenty use `vault login <>; ;    export VAULT_TOKEN=$(cat ~/.vault-token)` to guarantee that the last .vault-token is in the current shell env variable.

1. Validation table:

| Op                                                                 | Adam the Admin   | Dave the Dev     | Cicd    | Terraform |
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
vault login -method=userpass -path=userpass username=adam password=foo;   export VAULT_TOKEN=$(cat ~/.vault-token)
vault login -method=userpass -path=userpass-superadmins username=aadams password=foo;    export VAULT_TOKEN=$(cat ~/.vault-token)
vault login -method=userpass username=dave password=foo;     export VAULT_TOKEN=$(cat ~/.vault-token)
vault login -method=userpass username=cicd password=foo;    export VAULT_TOKEN=$(cat ~/.vault-token)



# test secretes
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

Add policy option to only read keys / parameters of secrets: 

https://github.com/hashicorp/vault/issues/10704


```
vault read -format=json sys/internal/ui/mounts|jq 
```

## Debugging: Active ACL:

https://developer.hashicorp.com/vault/api-docs/system/internal-ui-resultant-acl

```
vault read -format=json sys/internal/ui/resultant-acl
```


# Example Control Group:
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


## aadams, the superadmin: 
```
vault kv get secret/creds

vault kv get -field=username secret/creds

vault unwrap $WRAPPING_TOKEN
```

## dave the developer:
```
export WRAPPING_ACCESSOR=
vault write sys/control-group/request accessor=$WRAPPING_ACCESSOR

vault write sys/control-group/authorize accessor=$WRAPPING_ACCESSOR
```

## aadams the superadmin: 

```
export WRAPPING_TOKEN=
vault unwrap $WRAPPING_TOKEN
```


[ ] check audit
[ ] raise alert??

TODO: [ ] NOTE: Be careful in granting permissions to non-readonly identity endpoints. If a user can modify an entity, they can grant it additional privileges through policies. If a user can modify an alias they can login with, they can bind it to an entity with higher privileges
https://developer.hashicorp.com/vault/api-docs/secret/identity/entity-alias

