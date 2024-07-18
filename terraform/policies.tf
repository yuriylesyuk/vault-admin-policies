# resource "vault_policy" "admin_policy" {
#  name   = "admins"
#  policy = file("policies/admin_policy.hcl")
# }

resource "vault_policy" "this" {
    for_each = fileset("${path.module}/policies", "*.hcl")
    name = trimsuffix(each.value, ".hcl")
    policy = file("${path.module}/policies/${each.value}")
}
