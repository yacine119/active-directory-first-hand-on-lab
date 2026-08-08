#Requires -Module GroupPolicy
<#
.SYNOPSIS
    Creates and links the core GPOs for the zohdy.local lab, and applies
    security filtering for the two "everyone except X" scenarios.

.NOTES
    This script creates empty GPOs and links them — it does NOT set the
    individual policy settings inside each GPO (Control Panel disabled,
    CMD disabled, etc.), since those are typically set via the GPMC GUI
    or Set-GPRegistryValue for registry-based policies. See comments
    below for the registry paths used for each policy if you want to set
    them via Set-GPRegistryValue instead of the GUI.

    Run on the DC as a Domain Admin.
#>

$domain = "zohdy.local"

function New-LinkedGPO {
    param(
        [string]$Name,
        [string]$LinkTarget   # OU distinguished name, or the domain DN for domain-wide
    )
    if (-not (Get-GPO -Name $Name -ErrorAction SilentlyContinue)) {
        New-GPO -Name $Name | Out-Null
        Write-Host "Created GPO: $Name"
    }
    New-GPLink -Name $Name -Target $LinkTarget -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Linked $Name -> $LinkTarget"
}

$domainDN = (Get-ADDomain).DistinguishedName
$hrOU     = "OU=HR,$domainDN"
$salesOU  = "OU=Sales,$domainDN"

# --- Control Panel disabled: HR + Sales ---------------------------------
New-LinkedGPO -Name "disable-ControlPanel" -LinkTarget $hrOU
New-GPLink -Name "disable-ControlPanel" -Target $salesOU -ErrorAction SilentlyContinue | Out-Null

# Registry path used inside the GUI:
# User Configuration > Administrative Templates > Control Panel >
#   "Prohibit access to Control Panel and PC settings" = Enabled

# --- Disable CMD: HR only ---------------------------------------------------
New-LinkedGPO -Name "DisableCMD" -LinkTarget $hrOU
# User Configuration > Administrative Templates > System >
#   "Prevent access to the command prompt" = Enabled

# --- Disable external storage: HR only, excluding the HR manager -----------
New-LinkedGPO -Name "DisableExternalStorage" -LinkTarget $hrOU
# Computer/User Configuration > Administrative Templates > System >
#   Removable Storage Access > "All Removable Storage classes: Deny all access" = Enabled
#
# Exclude the HR manager (mzohdy) via security filtering:
#   1. Remove "Authenticated Users" from Security Filtering
#   2. Add "HR-group" to Security Filtering (Read + Apply Group Policy)
#   3. Explicitly deny "mzohdy" the "Apply Group Policy" permission
#      (Delegation tab > Advanced > Add user > Deny: Apply Group Policy)
$gpo = Get-GPO -Name "DisableExternalStorage"
Set-GPPermission -Name "DisableExternalStorage" -TargetName "Authenticated Users" -TargetType Group -PermissionLevel None -ErrorAction SilentlyContinue
Set-GPPermission -Name "DisableExternalStorage" -TargetName "HR-group" -TargetType Group -PermissionLevel GpoApply

# --- Remove Task Manager: domain-wide, excluding IT-group ------------------
New-LinkedGPO -Name "RemoveTaskManager" -LinkTarget $domainDN
# User Configuration > Administrative Templates > System > Ctrl+Alt+Del Options >
#   "Remove Task Manager" = Enabled
Set-GPPermission -Name "RemoveTaskManager" -TargetName "IT-group" -TargetType Group -PermissionLevel None -ErrorAction SilentlyContinue

# --- Remove "Properties" from This PC context menu: HR only ----------------
New-LinkedGPO -Name "RemoveProperteies" -LinkTarget $hrOU
# User Configuration > Administrative Templates > Windows Components > File Explorer >
#   "Remove Properties from the This PC context menu" = Enabled

# --- HR desktop URL shortcut: HR only ---------------------------------------
New-LinkedGPO -Name "HR-url" -LinkTarget $hrOU
# Deployed via Group Policy Preferences: User Configuration > Preferences >
#   Windows Settings > Shortcuts > New Shortcut
#   Target: http://hrapp.zohdy.local, Location: Desktop

Write-Host "`nDone. Core GPOs created and linked. Password policy and the" `
    "itadmin/local-admin GPP settings are configured separately — see" `
    "docs/setup-notes.md."
