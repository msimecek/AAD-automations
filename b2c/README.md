# Azure AD B2C automation scripts

## Files

PowerShell:

* `Create-AzureB2C.ps1`
  * end-to-end B2C tenant creation and provisioning - incl. app registrations, custom attribute, user flows and admin consent
* `Create-ServicePrincipal.ps1`
  * create service principal within B2C, update Azure DevOps variable group and upload secure file
* `Create-Users.ps1`
  * create sample users from the `users.json` file in the B2C tenant

Supporting files:

* `ROPC-userflow.json`
  * sample user flow definition for the ROPC flow
* `SignIn-userflow.json`
  * sample user flow definition for the sign in flow
* `users.json`
  * sample list of users, consumed by the `Create-Users.ps1` script

## How to use

Scripts are designed as a set of PowerShell functions, which work separately, or as a process invoked from a main function.

**Look at the source code, see what needs to be modified for your use case** and then use dot-sourcing to load the functions and then kick off the process.

### Create-AzureB2C

```powershell
. ./Create-AzureB2C.ps1
Initialize-B2CTenant -B2CTenantName mytenant -ResourceGroupName myrg -Location "Europe" -CountryCode "CZ"
```

Only the main function will trigger interactive login with Graph PowerShell. All functions are connected with the `-B2CTenantName` parameter.

Notable functions:

* `New-AzureADB2CTenant` - create empty B2C tenant in specified resource group.
* `Invoke-TenantInit` - initialize an empty B2C tenant.
* `Add-CustomAttribute` - create custom user attribute in the tenant.
* `Add-UserFlow` - create user flow based on JSON definition.
* `New-UIApp` & `New-WorkerApp` - example of two types of applications and admin consent to MS Graph.

### Create-ServicePrincipal

```powershell
. ./Create-ServicePrincipal.ps1
Create-ServicePrincipal -AppName "ADO Graph Client" -CertPath ./cert.cer -TenantId "mytenant.onmicrosoft.com"
```

Only the main function needs authentication to Microsoft Graph and it will trigger interactive login.

Notable functions:

* `New-Certificate` - create self-signed certificate for service principal.
* `Update-ADO` - upload secure file and update variable groups in Azure DevOps.
