#Requires -Module DhcpServer
<#
.SYNOPSIS
    Configures the DHCP scope, exclusion range, and PC01's reservation for
    the zohdy.local lab. Run on the DC after installing the DHCP Server
    role and authorizing it in AD (Add-DhcpServerInDC).

.NOTES
    Replace the MAC address placeholder with PC01's actual MAC address
    before running.
#>

$scopeId   = "192.168.1.0"
$scopeName = "zohdy's-scope"

# --- 1. Create scope -------------------------------------------------------
if (-not (Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Scope -Name $scopeName `
        -StartRange 192.168.1.40 `
        -EndRange 192.168.1.230 `
        -SubnetMask 255.255.255.0 `
        -State Active
    Write-Host "Created scope $scopeId"
}

# --- 2. Exclusion range ------------------------------------------------------
Add-DhcpServerv4ExclusionRange -ScopeId $scopeId `
    -StartRange 192.168.1.80 `
    -EndRange 192.168.1.85

# --- 3. Scope options (DNS + domain name) ------------------------------------
Set-DhcpServerv4OptionValue -ScopeId $scopeId `
    -DnsDomain "zohdy.local" `
    -DnsServer 192.168.1.2

# --- 4. Reservation for PC01 --------------------------------------------
# Replace with PC01's real MAC address, format AA-BB-CC-DD-EE-FF
$pc01Mac = "AA-BB-CC-DD-EE-FF"

Add-DhcpServerv4Reservation -ScopeId $scopeId `
    -IPAddress 192.168.1.40 `
    -ClientId $pc01Mac `
    -Name "PC01" `
    -Description "Reserved for lab client PC01"

Write-Host "`nDone. Scope, exclusion range, and PC01 reservation configured."
