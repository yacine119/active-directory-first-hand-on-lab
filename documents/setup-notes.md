# Setup Notes

High-level steps followed to build this lab through the GUI tools. Not a full
copy-paste tutorial — just enough detail to reproduce the environment or
explain it in an interview.

## 0. Virtual network (VMware)

Both VMs share one isolated virtual network (`192.168.1.0/24`). If VMware's
built-in DHCP service is enabled on that network, turn it off (Virtual Network
Editor), so the DC is the only DHCP server.

## 1. Domain Controller

1. Installed Windows Server 2025 (Standard, Evaluation) in VMware Workstation.
2. Set a static IP `192.168.1.2 /24`, renamed the computer to `DC`.
3. Installed the **AD DS** role (Server Manager → Add Roles and Features) and promoted the server to a new forest `zohdy.local`.
4. Verified DNS was installed alongside AD DS (required for SRV record registration).

## 2. Organizational Units, Users, Groups

1. In *Active Directory Users and Computers*, created three OUs under the domain root: `HR`, `Sales`, `IT`.
2. Created users in each OU (see the README for the structure and screenshots 02–04).
3. Created one security group per department and added that department's users to it.

## 3. DHCP

1. Installed the DHCP Server role on the DC.
2. Authorized the DHCP server in AD (an unauthorized server won't lease addresses on a domain network).
3. Created scope `zohdy's-scope` for `192.168.1.0/24`.
4. Address pool: `192.168.1.40` – `192.168.1.230`.
5. Excluded `192.168.1.80` – `192.168.1.85` (reserved for infrastructure use).
6. Set scope options: DNS server `192.168.1.2`, DNS domain `zohdy.local`.
7. Added a **reservation** for PC01's MAC address → `192.168.1.40`.

## 4. Client Join

1. Installed Windows 11 in a second VM (`PC01`) on the same virtual network.
2. Renewed the lease (`ipconfig /renew`). PC01 received `192.168.1.40` and DNS `192.168.1.2` from DHCP.
3. Joined `PC01` to `zohdy.local` via System Properties → Change → Domain, using domain admin credentials.

## 5. Group Policy

Created and linked GPOs per the table in the main README. General workflow:

1. Open **Group Policy Management Console** (GPMC).
2. Right-click the target OU (or domain root for domain-wide policies) → *Create a GPO in this domain, and link it here.*
3. Edit the GPO → go to the relevant path under *User Configuration* or *Computer Configuration* → *Administrative Templates* (or Group Policy Preferences for shortcuts and the local admin settings).
4. For policies that apply to "everyone except one user/group" (security filtering), I used the **Scope** and **Delegation** tabs:
   1. **Scope → Security Filtering**: choose who the policy applies to.
   2. **Delegation → Advanced**: add the excluded user or group (the HR manager for `DisableExternalStorage`, `IT-group` for `RemoveTaskManager`) and **Deny** *Apply group policy*.
   3. Best practice: leave **Read** for Authenticated Users on the GPO, otherwise the GPO may not apply to anyone (MS16-072). The Settings reports in screenshots 05–07 show the default delegation entries were removed from those GPOs, which is listed as a limitation in the README.
5. Ran `gpupdate /force` on the client (or `Invoke-GPUpdate` from the DC) and confirmed with `gpresult /r` on the client.

### Password / Lockout Policy

Configured in a GPO named `PasswordPolicy`, linked at the **domain root** (the Default Domain Policy also exists there). Account policies only take effect from the domain level, so a GPO linked to an OU would be ignored. Per-group policies need Fine-Grained Password Policies (PSOs) via Active Directory Administrative Center; PSOs apply to users and global security groups, not OUs. See screenshot `10-password-policy-settings.png`.

Settings used:
- Enforce password history: 2 passwords remembered
- Maximum password age: 90 days
- Minimum password age: 30 days
- Minimum password length: 6 characters
- Password must meet complexity requirements: Enabled
- Account lockout threshold: 5 invalid attempts
- Account lockout duration: 60 minutes
- Reset account lockout counter after: 10 minutes

## 6. Local Admin via GPO

Used **Group Policy Preferences** (Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups), in two GPOs linked at the domain root:
- `itadmin`: creates a local user `itadmin` on domain-joined machines.
- `IT-group-Admins`: adds the `IT-group` domain security group to the local `Administrators` group.

> **Limitation:** GPP-based passwords are stored in SYSVOL and are recoverable by any domain user (MS14-025). Acceptable in an isolated lab; replace with Windows LAPS in anything real.

## 7. Verification

- `dcdiag /v` on the DC to confirm domain health.
- `nltest /dsgetdc:zohdy.local` from the client to confirm DC discovery.
- `gpresult /h report.html` on PC01 to confirm which GPOs applied and in what order.
- Manually tested each restriction (Control Panel, CMD, storage, Task Manager) logged in as an affected user vs. an excluded one (see the test table in the README).

## Known Issues Encountered

| Issue | Cause | Fix |
|---|---|---|
| Recurring NETLOGON Event ID 5781 in System log | DNS SRV records for the DC not registering cleanly | Confirmed single active NIC, ran `ipconfig /registerdns`, verified with `dcdiag /test:dns` |
| DHCP pool start address overlapped intended static client IP | Pool started at `.40`, same address planned for PC01 | Replaced the static IP plan with a DHCP reservation |
