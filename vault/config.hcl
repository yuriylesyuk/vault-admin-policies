cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://127.0.0.1:8200"


storage "raft" {
   path    = "/home/ec2-user/vault-admin-policies/vault/data"
   node_id = "vault_1"
}

listener "tcp" {
   address = "0.0.0.0:8200"
   cluster_address = "127.0.0.1:8201"
   tls_disable = true
}

ui = true
disable_mlock = true
