path "secret/metadata/*" {
  capabilities =  ["list"]
}

path "secret/data/*" {
  capabilities =  ["read", "list"]
}
