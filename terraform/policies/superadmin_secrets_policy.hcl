path "secret/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
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

