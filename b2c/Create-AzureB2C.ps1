# Windows PowerShell and PowerShell Core are supported.
# - Microsoft.Graph PowerShell module needs to be installed.
# - Azure CLI needs to be installed and authenticated for the owning tenant.
#
# Usage:
# - dot-source in a PS script: . ./Create-AzureB2C.ps1
# - invoke individual functions, or the main one: Initialize-B2CTenant -B2CTenantName mytenant -ResourceGroupName myrg -Location "Europe" -CountryCode "CZ"

function Initialize-B2CTenant {
  [CmdletBinding()] # indicate that this is advanced function (with additional params automatically added)
  param (
    [Parameter(Mandatory = $true, HelpMessage = "B2C tenant name, without the '.onmicrosoft.com'.")]
    [string] $B2CTenantName,
    
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group to put the B2C resource into. Will be created if it does not exist.")]
    [string] $ResourceGroupName,

    [Parameter()]
    [ValidateSet('United States','Europe','Asia Pacific', 'Australia')]
    [string] $Location = 'Europe',
    
    [Parameter(HelpMessage = "Two letter country code (e.g. 'US', 'CZ', 'DE'). https://docs.microsoft.com/en-us/azure/active-directory-b2c/data-residency")]
    [ValidateSet('AU', 'NZ', 'AF', 'HK', 'IN', 'ID', 'JP', 'KR', 'MY', 'PH', 'SG', 'LK', 'TW', 'TH', 'DZ', 'AT', 'AZ', 'BH', 'BY', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EG', 'EE', 'FT', 'FR', 'DE', 'GR', 'HU', 'IS', 'IE', 'IL', 'IT', 'JO', 'KZ', 'KE', 'KW', 'LV', 'LB', 'LI', 'LT', 'LU', 'ML', 'MT', 'ME', 'MA', 'NL', 'NG', 'NO', 'OM', 'PK', 'PL', 'PT', 'QA', 'RO', 'RU', 'SA', 'RS', 'SK', 'ST', 'ZA', 'ES', 'SE', 'CH', 'TN', 'TR', 'UA', 'AE', 'GB', 'US', 'CA', 'CR', 'DO', 'SV', 'GT', 'MX', 'PA', 'PR', 'TT')]
    [string] $CountryCode = "GB"
  )

  if (Get-Module -ListAvailable -Name Microsoft.Graph) {
    Write-Host "Module Microsoft.Graph exists."
  }
  else {
      throw "Module Microsoft.Graph is not installed yet. Please install it first! Run 'Install-Module Microsoft.Graph'."
  }

  # Create the B2C tenant resource in Azure
  New-AzureADB2CTenant `
    -B2CTenantName $B2CTenantName `
    -Location $Location `
    -CountryCode $CountryCode `
    -AzureResourceGroup $ResourceGroupName

  # Call the init API
  Invoke-TenantInit `
   -B2CTenantName $B2CTenantName

  Write-Host "Interactive login to the Graph API. Watch for a newly opened browser window (or device flow instructions) and complete the sign in."
  # Interactive login, so that we don't have to create a separate service principal and handle secrets.
  # Make sure that the user has administrative permissions in the tenant.
  Connect-MgGraph -TenantId "$($B2CTenantName).onmicrosoft.com" -Scopes "User.ReadWrite.All", "Application.ReadWrite.All", "Directory.AccessAsUser.All", "Directory.ReadWrite.All"

  # Add custom attribute called "GameMaster"
  Add-CustomAttribute `
    -B2CTenantName $B2CTenantName `
    -AttributeName "GameMaster" `
    -Description "Indicates whether this user has Game Master privileges"

  # Add user signin user flow
  Add-UserFlow `
    -B2CTenantName $B2CTenantName `
    -DefinitionFilePath ./SignIn-userflow.json

  # Add ROPC signin user flow
  Add-UserFlow `
    -B2CTenantName $B2CTenantName `
    -DefinitionFilePath ./ROPC-userflow.json

  # Create Application for the UI
  $uiApp = New-UIApp `
    -B2CTenantName $B2CTenantName

  # Create the Graph Client application for the Worker
  $workerApp = New-WorkerApp

  # Create demo users
  . ./Create-Users.ps1 # dot-sourcing only now, to prevent interference with the previous steps

  $createdUsers = Import-Users `
    -B2CTenantName $B2CTenantName

  # TODO: Integrate Create-ServicePrincipal.ps1

  return @{
    UIAppClientID = $uiApp.ClientID
    WorkerClientID = $workerApp.ClientID
    WorkerClientSecret = $workerApp.ClientSecret
    Users = $createdUsers
  }
}

#
# Create new Azure AD B2C tenant in a specific subscription and resource group.
# Must be followed by Invoke-TenantInit to finalize the creation of default apps.
#
# Required: Azure CLI authenticated for the target subscription.
# Required: Resource provider: "Microsoft.AzureActiveDirectory". The function will attempt to register if not done so yet.
#   az provider register --namespace Microsoft.AzureActiveDirectory
#
# Azure PowerShell Alternative: Invoke-AzRestMethod
function New-AzureADB2CTenant {
  param(
    # Tenant name without the '.onmicrosoft.com' part.
    [string] $B2CTenantName,

    # Can be one of 'United States', 'Europe', 'Asia Pacific', or 'Australia' (preview).
    [Parameter()]
    [ValidateSet('United States','Europe','Asia Pacific', 'Australia')]
    [string] $Location,

    # Where data resides. Two letter country code (e.g. 'US', 'CZ', 'DE').
    # Valid country codes are listed here: https://docs.microsoft.com/en-us/azure/active-directory-b2c/data-residency
    [Parameter(HelpMessage = "Two letter country code (e.g. 'US', 'CZ', 'DE'). https://docs.microsoft.com/en-us/azure/active-directory-b2c/data-residency")]
    [ValidateSet('AU', 'NZ', 'AF', 'HK', 'IN', 'ID', 'JP', 'KR', 'MY', 'PH', 'SG', 'LK', 'TW', 'TH', 'DZ', 'AT', 'AZ', 'BH', 'BY', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EG', 'EE', 'FT', 'FR', 'DE', 'GR', 'HU', 'IS', 'IE', 'IL', 'IT', 'JO', 'KZ', 'KE', 'KW', 'LV', 'LB', 'LI', 'LT', 'LU', 'ML', 'MT', 'ME', 'MA', 'NL', 'NG', 'NO', 'OM', 'PK', 'PL', 'PT', 'QA', 'RO', 'RU', 'SA', 'RS', 'SK', 'ST', 'ZA', 'ES', 'SE', 'CH', 'TN', 'TR', 'UA', 'AE', 'GB', 'US', 'CA', 'CR', 'DO', 'SV', 'GT', 'MX', 'PA', 'PR', 'TT')]
    [string] $CountryCode,

    # Under which Azure subscription will this B2C tenant reside. If not provided, use the current subscription from Azure CLI.
    [string] $AzureSubscriptionId = $null,

    # Under which Azure resource group will this B2C tenant reside.
    [string] $AzureResourceGroup
  )

  if (!$AzureSubscriptionId) {
    Write-Host "Getting subscription ID from the current account..."
    $AzureSubscriptionId = $(az account show --query "id" -o tsv)
    Write-Host $AzureSubscriptionId
  }

  $aadProviderRegState = $(az provider show -n Microsoft.AzureActiveDirectory --query "registrationState" -o tsv)
  if($aadProviderRegState -ne "Registered")
  {
    Write-Host "Resource Provider 'Microsoft.AzureActiveDirectory' not registered yet. Registering now..."
    az provider register --namespace Microsoft.AzureActiveDirectory

    while($(az provider show -n Microsoft.AzureActiveDirectory --query "registrationState" -o tsv) -ne "Registered")
    {
      Write-Host "Resource Provider registration not yet finished. Waiting..."
      Start-Sleep -Seconds 10
    }
    Write-Host "Resource Provider registration finished."
  }

  Write-Host "Checking if Resource Group $AzureResourceGroup exists..."
  $checkRg = az group exists --name $AzureResourceGroup | ConvertFrom-Json

  if($LastExitCode -ne 0)
  {
      throw "Error on using Azure CLI. Make sure the CLI is installed, up-to-date and you are signed in. Run 'az login' to sign in."
  }

  if (!$checkRg) {
    Write-Warning "Resource Group $AzureResourceGroup does not exist. Creating..."
    az group create --name $AzureResourceGroup --location $(($Location.ToLower()).replace(' ','')) # Everybody likes Ireland, so we put the RG there if it does not exist
  }

  $resourceId = "/subscriptions/$AzureSubscriptionId/resourceGroups/$AzureResourceGroup/providers/Microsoft.AzureActiveDirectory/b2cDirectories/$B2CTenantName.onmicrosoft.com"

  # Check if tenant already exists
  Write-Host "Checking if tenant '$B2CTenantName' already exists..."
  az resource show --id $resourceId | Out-Null
  if($LastExitCode -eq 0) # No error means, the resource exists
  {
    Write-Warning "Tenant '$B2CTenantName' already exists. Not attempting to recreate it."
    return
  }

  $reqBody=@"
  {
    "location":"$($Location)",
    "sku": {
        "name":"Standard",
        "tier":"A0"
    },
    "properties": {
        "createTenantProperties": {
            "displayName":"$($B2CTenantName)",
            "countryCode":"$($CountryCode)"
        }
    }
  }
"@ # No whitespace permitted before the closing sequence.

  # Flatten the JSON to make Azure CLI happy, otherwise it complains about incorrect content type.
  $reqBody = $reqBody.Replace("`n", "").Replace("`"", "\`"")

  Write-Host "Creating B2C tenant $B2CTenantName..."
  # https://docs.microsoft.com/en-us/rest/api/activedirectory/b2c-tenants/create
  az rest --method PUT --url "https://management.azure.com$($resourceId)?api-version=2019-01-01-preview" --body $reqBody

  if($LastExitCode -ne 0)
  {
      throw "Error on creating new B2C tenant!"
  }

  Write-Host "*** B2C Tenant creation started. It can take a moment to complete."

  do
  {
    Write-Host "Waiting for 30 seconds for B2C tenant creation..."
    Start-Sleep -Seconds 30

    az resource show --id $resourceId 
  }
  while($LastExitCode -ne 0)
}

#
# Finalize initialization of newly created B2C tenant.
# This function needs to be called once the tenant is created and before any other steps, because it creates the b2c-extensions-app.
#
# Required: Azure CLI authenticated with owner permissions for the tenant.
function Invoke-TenantInit {
  param (
    [string] $B2CTenantName
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant "$B2CTenantId" --query accessToken -o tsv)

  # Invoke tenant initialization which happens through the portal automatically.
  # Ref: https://stackoverflow.com/questions/67706798/creation-of-the-b2c-extensions-app-by-script
  Write-Host "Invoking tenant initialization..."
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/tenants/GetAndInitializeTenantPolicy?tenantId=$($B2CTenantId)&skipInitialization=false" `
    -Method "GET" `
    -Headers @{
      "Authorization" = "Bearer $($managementAccessToken)"
    }
}

#
# Create a custom user attribute in the tenant.
#
# Requires: Azure CLI authenticated with owner permissions for the tenant.
# Alternatively, the /beta/identity/userFlowAttributes Graph endpoint can be used.
function Add-CustomAttribute {
  param (
    [string] $B2CTenantName,
    
    [string] $AttributeName,
    [string] $Description,
    [string] $DataType = 2
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant $B2CTenantId --query accessToken -o tsv)
  $reqBody = @"
{
  "dataType": $($DataType),
  "label": "$($AttributeName)",
  "adminHelpText": "$($Description)",
  "userInputType": 1,
  "userAttributeOptions": [],
  "attributeType": 3
}
"@ # no whitespace permitted before the closing sequence

  # Create the attribute using the same method as the Portal.
  Write-Host "Creating custom attribute $($AttributeName)..."
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/userAttribute?tenantId=$($B2CTenantId)" `
    -Method "POST" `
    -Headers @{
      "Authorization" = "Bearer $($managementAccessToken)";
      "Content-Type" = "application/json"
    } `
    -Body $reqBody
}

#
# Create user flow based on JSON definition from a file.
#
# Requires: Azure CLI authenticated with owner permissions for the tenant.
function Add-UserFlow {
  param(
    [string] $B2CTenantName,
    [string] $DefinitionFilePath
  )

  $B2CTenantId = "$($B2CTenantName).onmicrosoft.com"

  # Get access token for the B2C tenant with audience "management.core.windows.net".
  $managementAccessToken = $(az account get-access-token --tenant $B2CTenantId --query accessToken -o tsv)

  Write-Host "Creating $($DefinitionFilePath) user flow..."
  $signinFlowContent = Get-Content $DefinitionFilePath
  # Using WebRequest here, because Microsoft Graph is currently not able to create user flows with custom attributes.
  Invoke-WebRequest -Uri "https://main.b2cadmin.ext.azure.com/api/adminuserjourneys?tenantId=$($B2CTenantId)" `
    -Method "POST" `
    -Headers @{
      "Authorization" = "Bearer $($managementAccessToken)";
      "Content-Type" = "application/json"
    } `
    -Body $signinFlowContent
}

#
# Creates a B2C application registration to be used for users to sign-in.
#
# This includes custom scope called Games.Access.
#
function New-UIApp {
  param (
    [string] $B2CTenantName
  )

  # Create the Games.Access permission scope
  $gamesAccessScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
  $gamesAccessScope.AdminConsentDescription = "Allows the app to access to game data on behalf of a user."
  $gamesAccessScope.AdminConsentDisplayName = "Access games"
  $gamesAccessScope.Id = New-Guid
  $gamesAccessScope.IsEnabled = $true
  $gamesAccessScope.Type = "Admin"
  $gamesAccessScope.Value = "Games.Access"

  # Create the UI application
  $uiApp = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
  $uiApp.DisplayName = "UI application"
  $uiApp.SignInAudience = "AzureADandPersonalMicrosoftAccount"
  $uiApp.Spa.RedirectUris = "http://localhost:8080"
  $uiApp.Web.ImplicitGrantSettings.EnableAccessTokenIssuance = $true
  $uiApp.Web.ImplicitGrantSettings.EnableIdTokenIssuance = $true
  $uiApp.IsFallbackPublicClient = $true
  $uiApp.Api.Oauth2PermissionScopes = $gamesAccessScope

  Write-Host "Creating UI application..."
  $uiApp = New-MgApplication -BodyParameter $uiApp
  Write-Host "Successfully created UI app with applicationId $($uiApp.AppId)"

  # Adding Games.Access API permission
  $gamesRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $gamesRRA.ResourceAccess = @{ Id = $gamesAccessScope.Id; Type = "Scope" }
  $gamesRRA.ResourceAppId = $uiApp.AppId # ID of the resource that application requires access to - it's the same in our case

  # Well-known ID for offline_access = 7427e0e9-2fba-42fe-b0c0-848c9e6a8182
  $offlineAccessScope = @{ Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"; Type = "Scope" }

  # Well-known ID for openid = 37f7f235-527c-4136-accd-4a02d197296e
  $openidScope = @{ Id = "37f7f235-527c-4136-accd-4a02d197296e"; Type = "Scope" }

  # offline_access and openid scopes are tied to the same app
  $graphRRA = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRRA.ResourceAccess = @($offlineAccessScope, $openidScope)
  $graphRRA.ResourceAppId = "00000003-0000-0000-c000-000000000000" # Well-known ID, the same across all tenants

  $resourceAccessList = @(
    $gamesRRA
    $graphRRA
  )

  # Update UI app with the API permission and identifier URI.
  # Identifier URI has to be based on the App ID in our case, so the app had to be created first.
  Write-Host "Assigning Games.Access and openid permissions for the UI application..."
  Update-MgApplication `
    -ApplicationId $uiApp.Id `
    -RequiredResourceAccess $resourceAccessList `
    -IdentifierUris "https://$($B2CTenantName).onmicrosoft.com/$($uiApp.AppId)"

  # Service principal for the application is not created automatically.
  # It's needed for admin consent etc.
  $servicePrincipal = New-MgServicePrincipal -AppId $uiApp.AppId

  # Admin Consent - for the UI app this is OAuth2 Permission Grant
  Write-Host "Updating admin consent for the UI app..."
  New-MgOauth2PermissionGrant `
    -ConsentType AllPrincipals `
    -ClientId $servicePrincipal.Id `
    -Scope $gamesAccessScope.Value `
    -ResourceId $servicePrincipal.Id | Out-Null

  Write-Host "*** Azure AD B2C Application '$($uiApp.DisplayName)' created."
  Write-Host "*** Client ID: $($uiApp.AppId)"

  return @{
    ClientID = $uiApp.AppId
  }
}

#
# Creates an AAD application to be used by a headless worker to access the Graph API to resolve user names.
#
function New-WorkerApp {
  # Prepare Microsoft Graph access for user details
  # User.Read.All scope is pre-defined in the Microsoft.Graph global application - App ID is hardcoded here and doesn't change across tenants. The service principal ID changes per tenant though.
  # Static appId for Microsoft Graph across Azure AD - https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/verify-first-party-apps-sign-in#application-ids-for-commonly-used-microsoft-applications
  $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

  # All scopes and IDs can be found with this Graph query: https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '00000003-0000-0000-c000-000000000000'&$select=appRoles, oauth2PermissionScopes
  $userReadAllScope = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess
  $userReadAllScope.Id = "df021288-bdef-4463-88db-98f22de89214" # Well-known ID, the same across all tenants
  $userReadAllScope.Type = "Role" # Application permissions

  $graphRequiredResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
  $graphRequiredResourceAccess.ResourceAccess = $userReadAllScope
  $graphRequiredResourceAccess.ResourceAppId =  $graphServicePrincipal.AppId

  Write-Host "Creating worker application..."
  $workerApp = New-MgApplication `
                          -DisplayName "Worker application" `
                          -SignInAudience "AzureADandPersonalMicrosoftAccount" `
                          -RequiredResourceAccess $graphRequiredResourceAccess

  Write-Host "Successfully created worker graph client app with clientId $($workerApp.AppId)"

  # Similar as with the UI, we need explicit service principal here.
  $workerServicePrincipal = New-MgServicePrincipal -AppId $workerApp.AppId

  # Create secret for the app. This has to be done after the app is created.
  $secret = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential
  $secret.KeyId = New-Guid
  $secret.DisplayName = "secret"

  Write-Host "Creating secret for the Worker application..."
  $secret = Add-MgApplicationPassword -ApplicationId $workerApp.Id -PasswordCredential $secret

  # Admin Consent - for Microsoft Graph this is a role assignment
  Write-Host "Updating admin consent for the Worker app..."

  New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $workerServicePrincipal.Id `
    -ResourceId $graphServicePrincipal.Id `
    -AppRoleId $userReadAllScope.Id `
    -PrincipalId $workerServicePrincipal.Id | Out-Null

  Write-Host "*** Azure AD B2C Application '$($workerApp.DisplayName)' created."
  Write-Host "*** Client ID: $($workerApp.AppId)"
  Write-Host "*** Client Secret: $($secret.SecretText)"

  return @{
    ClientID = $workerApp.AppId
    ClientSecret = $secret.SecretText
  }
}