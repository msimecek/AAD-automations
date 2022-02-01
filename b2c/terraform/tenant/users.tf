#
# This doesn't work in B2C.
#
# # load user list from file
# # iterate and create dynamically
# locals {
#   users_file = jsondecode(file("users.json"))
# }

# data "azuread_users" "users" {
#   return_all = true
# }

# data "azuread_user" "oneuser" {
#   user_principal_name = "a83de67d-400b-404a-8116-6bfda49e6f90@tenant.onmicrosoft.com"
# }

# resource "azuread_user" "user" {
#   for_each = {
#     for user in local.users_file.users : user.email => user
#   } 

#   user_principal_name = each.key
#   display_name        = each.value.displayName
#   password            = "SecretP@sswd99!"
# }

# output "allusers" {
#   value = data.azuread_users.users
# }

# output "oneuser" {
#   value = data.azuread_user.oneuser
# }