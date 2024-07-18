data "vault_identity_group" "admins" {
  group_name = "<ADMIN-TEAM>"
}

data "vault_auth_backend" "userpass" {
  path = "userpass"
}
