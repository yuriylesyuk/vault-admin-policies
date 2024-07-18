

# Allow viewing system configuration settings
path "sys/*" {
  capabilities = ["read", "list", "sudo"]

}

# Allow managing mounts
path "sys/mounts/*" {
  capabilities = ["create", "update", "delete", "read", "list"]
}

# Deny access to secrets
path "secret/*" {
  capabilities = ["deny"]
}


# Deny policy management

## sic! sys/policy
##      sys/policies/[acl|rg|egp]
path "sys/policies/*" {
  capabilities = ["deny"]
}
