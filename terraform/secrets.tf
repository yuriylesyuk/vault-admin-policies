resource "vault_mount" "secret" {
  path = "secret"
  type = "kv-v2"
}

