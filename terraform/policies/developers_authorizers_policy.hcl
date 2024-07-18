# To check/aprove control group request status
path "sys/control-group/*" {
    capabilities = ["create", "update"]
}
