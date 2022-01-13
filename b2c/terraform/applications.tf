# variable "b2cTenantName" {
#   type = string
# }

data "azuread_client_config" "current" {}
data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing   = true
}

resource "random_uuid" "gameaccess_scope_id" {}

#
# Application with certificate
#
resource "azuread_application" "graph_worker" {
  display_name     = "GraphWorker_App"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = ["http://localhost/"]
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
      type = "Role"
    }
  }
}

resource "azuread_application_certificate" "graph_worker" {
  application_object_id = azuread_application.graph_worker.id
  type                      = "AsymmetricX509Cert"
  value                     = filebase64("./certs/graphworker-cert.cer")
  end_date_relative         = "17532h" # 2 years
}

resource "azuread_service_principal" "graph_worker" {
  application_id = azuread_application.graph_worker.application_id
}

resource "azuread_app_role_assignment" "graph_worker" {
  app_role_id         = azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
  principal_object_id = azuread_service_principal.graph_worker.object_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
}

#
# Application with custom scope
#
resource "azuread_application" "api" {
  display_name     = "Api"
  owners           = [data.azuread_client_config.current.object_id]
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  identifier_uris = [ "https://${azurerm_aadb2c_directory.tenant.domain_name}/apinka" ]

  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      admin_consent_description  = "Allows the app to access to game data on behalf of a user."
      admin_consent_display_name = "Access Games"
      enabled                    = true
      id                         = random_uuid.gameaccess_scope_id.result
      type                       = "Admin"
      value                      = "Games.Access"
    }
  }

  web {
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled = true
    }
  }

  single_page_application {
    redirect_uris = [ "http://localhost:8080/" ]
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    # Terraform datasource of well_known IDs doesn't contain openid and offline_access
    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e" # openid
      type = "Scope"
    }

    resource_access {
      id   = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182" # offline_access
      type = "Scope"
    }
  }
}

# resource "azuread_service_principal" "api" {
#   application_id = azuread_application.api.application_id
# }


# # Assign access to self.
# resource "azuread_app_role_assignment" "api" {
#   app_role_id         = random_uuid.gameaccess_scope_id.result
#   principal_object_id = azuread_service_principal.api.object_id
#   resource_object_id  = azuread_service_principal.api.object_id
# }
