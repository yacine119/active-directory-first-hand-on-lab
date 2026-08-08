#Requires -Module ActiveDirectory
<#
.SYNOPSIS
    Creates the OU structure, sample users, and department groups for the
    zohdy.local lab. Run on the domain controller as a Domain Admin.

.NOTES
    This is the automated version of the manual steps documented in
    docs/setup-notes.md — part of the "bigger version" roadmap in the
    README (automate the environment build instead of clicking through
    the GUI every time).
#>

$domainDN = (Get-ADDomain).DistinguishedName   # e.g. DC=zohdy,DC=local

# --- 1. Organizational Units -------------------------------------------------
$ous = @("HR", "Sales", "IT")

foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $true
        Write-Host "Created OU: $ou"
    }
}

# --- 2. Users ------------------------------------------------------------
# Format: DisplayName, SamAccountName, OU, Password
$defaultPassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force

$users = @(
    @{ Name = "Mohamed Zohdy"; Sam = "mohamed.zohdy"; OU = "HR" }
    @{ Name = "Salma Mohamed"; Sam = "salma.mohamed"; OU = "HR" }
    @{ Name = "Alaa Kamal";    Sam = "alaa.kamal";   OU = "Sales" }
    @{ Name = "Ahmed Nabil";   Sam = "ahmed.nabil";   OU = "IT" }
)

foreach ($u in $users) {
    $ouPath = "OU=$($u.OU),$domainDN"
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $u.Name `
            -SamAccountName $u.Sam `
            -UserPrincipalName "$($u.Sam)@zohdy.local" `
            -Path $ouPath `
            -AccountPassword $defaultPassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true
        Write-Host "Created user: $($u.Name) in $($u.OU)"
    }
}

# --- 3. Department Groups -------------------------------------------------
$groups = @(
    @{ Name = "HR-group";    OU = "HR";    Members = @("mzohdy", "smohamed") }
    @{ Name = "sales-group"; OU = "Sales"; Members = @("akamal") }
    @{ Name = "IT-group";    OU = "IT";    Members = @("anabil") }
)

foreach ($g in $groups) {
    $ouPath = "OU=$($g.OU),$domainDN"
    if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $ouPath
        Write-Host "Created group: $($g.Name)"
    }
    Add-ADGroupMember -Identity $g.Name -Members $g.Members
}

Write-Host "`nDone. OUs, users, and groups created."
