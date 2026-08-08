# Setup Notes

High-level steps followed to build this lab. Not a full copy-paste
tutorial — just enough detail to reproduce the environment or explain it
in an interview.

## 1. Domain Controller

1. Installed Windows Server 2025 (Standard, Evaluation) in VMware
   Workstation.
2. Set a static IP: `192.168.1.2 /24`, renamed the computer to `DC`.
3. Installed the **AD DS** role, promoted the server to a new forest:
   `zohdy.local`.
4. Verified DNS was installed alongside AD DS (required for SRV record
   registration).

## 2. Organizational Units, Users, Groups

1. Created three OUs under the domain root: `HR`, `Sales`, `IT`.
2. Created users in each OU (see README for the full list).
3. Created one security group per department and added that
   department's users to it.

## 3. Client Join

1. Installed Windows 10/11 in a second VM (`PC01`).
2. Configured DHCP (see below) so PC01 would consistently receive
   `192.168.1.40`.
3. Set DNS on the client to point at the DC (`192.168.1.2`) so it could
   resolve the domain.
4. Joined `PC01` to `zohdy.local` via System Properties → Change →
   Domain, using domain admin credentials.

## 4. DHCP

1. Installed the DHCP Server role on the DC.
2. Created scope `zohdy's-scope` for `192.168.1.0/24`.
3. Address pool: `192.168.1.40` – `192.168.1.230`.
4. Excluded `192.168.1.80` – `192.168.1.85` (reserved for infrastructure
   use).
5. Added a **reservation** for PC01's MAC address → `192.168.1.40`, so it
   always gets the same address without needing a manual static IP.
6. Authorized the DHCP server in AD (required — an unauthorized DHCP
   server won't lease addresses on a domain network).

## 5. Group Policy

Created and linked GPOs per the table in the main README. General
workflow for each:

1. Open **Group Policy Management Console** (GPMC).
2. Right-click the target OU (or domain root, for domain-wide policies)
   → *Create a GPO in this domain, and link it here.*
3. Edit the GPO → navigate to the relevant policy path under
   *User Configuration* or *Computer Configuration* → *Administrative
   Templates* (or Group Policy Preferences for the local admin account).
4. For policies that needed to apply to "everyone except one user/group,"
   used the **Scope → Security Filtering** tab: removed *Authenticated
   Users*, added the specific group that *should* get the policy, then
   added the excluded user/group with the **Deny** permission on
   *Apply Group Policy* (via Delegation → Advanced).
5. Ran `gpupdate /force` on the client / `Invoke-GPUpdate` from the DC to
   test, then confirmed with `gpresult /r` on the client.

### Password / Lockout Policy

Configured under **Default Domain Policy** (linked at the domain root),
*not* a GPO linked to an OU — fine-grained, per-OU password policy
requires PSOs (Fine-Grained Password Policies) via Active Directory
Administrative Center, which regular GPOs cannot override at the OU
level for these specific settings.

Settings used:
- Maximum password age: 90 days
- Minimum password length: 6 characters
- Password must meet complexity requirements: Enabled
- Enforce password history: 2 passwords remembered
- Account lockout threshold: 5 invalid attempts
- Account lockout duration: 60 minutes

## 6. Local Admin via GPO

Used **Group Policy Preferences** (Computer Configuration → Preferences
→ Control Panel Settings → Local Users and Groups) to:
- Create a local user `itadmin` with a preset password on every
  domain-joined machine.
- Add the `IT-Group` domain security group to the local
  `Administrators` group on every domain-joined machine.

## 7. Verification

- `dcdiag /v` on the DC to confirm domain health.
- `nltest /dsgetdc:zohdy.local` from the client to confirm DC discovery.
- `gpresult /h report.html` on PC01 to confirm which GPOs actually
  applied and in what order.
- Manually tested each restriction (Control Panel, CMD, storage, Task
  Manager) logged in as an affected user vs. an excluded one.

## Known Issues Encountered

| Issue | Cause | Fix |
|---|---|---|
| Recurring NETLOGON Event ID 5781 in System log | DNS SRV records for the DC not registering cleanly | Confirmed single active NIC, ran `ipconfig /registerdns`, verified with `dcdiag /test:dns` |
| DHCP pool start address overlapped intended static client IP | Pool started at `.40`, same address planned for PC01 | Replaced plan with a DHCP reservation instead of a static IP, so DHCP itself won't hand `.40` to anyone else |
