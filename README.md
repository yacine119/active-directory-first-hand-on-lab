# Active Directory Domain Lab — zohdy.local

A hands-on Windows Server lab where I built a small but complete Active
Directory environment from scratch: domain setup, OU structure, users and
groups, Group Policy Objects for real-world scenarios, DHCP, and a
domain-joined client — all inside VMware Workstation.

This isn't a tutorial walkthrough. It's a self-assigned lab designed to
mimic a small company's IT environment, with the kind of messy, specific
requirements (exclude one manager from a restriction, scope a GPO to one
department, lock out the whole domain except IT) that show up in real
sysadmin work.

## Architecture

![Network Diagram](docs/network-diagram.svg)

| Role | Hostname | IP | OS |
|---|---|---|---|
| Domain Controller | DC | 192.168.1.2 | Windows Server 2025 Standard (Eval) |
| Domain-joined client | PC01 | 192.168.1.40 (reserved via DHCP) | Windows 10/11 |

**Domain:** `zohdy.local`

## OU & User Structure

```
zohdy.local
├── HR
│   ├── Mohamed Zohdy          (user — HR manager, excluded from storage lockdown)
│   ├── Salma Mohamed          (user)
│   └── HR-group               (security group)
├── Sales
│   ├── Alaa Kamal              (user)
│   └── sales-group             (security group)
└── IT
    ├── Ahmed Nabil              (user)
    └── IT-group                 (security group)
```

## Group Policy Objects

| GPO | Scope | What it does |
|---|---|---|
| `disable-ControlPanel` | HR, Sales OUs | Hides/disables Control Panel |
| `DisableCMD` | HR OU | Disables `cmd.exe` |
| `DisableExternalStorage` | HR OU (security-filtered to exclude HR manager) | Blocks USB/removable storage for all HR users except Mohamed Zohdy |
| `RemoveTaskManager` | Domain-wide (security-filtered to exclude IT-group) | Removes Task Manager for every domain user except IT |
| `RemoveProperteies` | HR OU | Removes "Properties" from the This PC right-click context menu |
| `PasswordPolicy` | Domain (linked at domain root — required for password/lockout settings) | Max age 90 days, min length 6, complexity on, password history 2, account lockout after 5 attempts for 60 minutes |
| `HR-url` | HR OU | Deploys `http://hrapp.zohdy.local` shortcut to all HR desktops |
| `itadmin` | Domain-wide | Creates a local admin account (`itadmin`) on every domain-joined computer via GPP |
| Local Administrators (via GPO) | Domain-wide | Adds `IT-Group` to the local Administrators group on all machines |

**Why security filtering instead of a separate OU for exceptions?**
Pulling one user (the HR manager) or one group (IT) out into a whole new OU
just to change GPO scope would break the department-based OU model for no
real benefit. Security filtering (and in a couple of spots, Item-Level
Targeting) lets a single GPO apply to "everyone in this OU except X"
without restructuring the directory — which is how this is actually done
in production environments.

## DHCP Configuration

- Scope: `192.168.1.0/24` ("zohdy's-scope")
- Address pool: `192.168.1.40` – `192.168.1.230`
- Exclusion range: `192.168.1.80` – `192.168.1.85`
- `PC01` receives `192.168.1.40` via a **DHCP reservation** (not a static
  IP on the client, and not left to chance in the general pool) so it's
  guaranteed the same address every time without conflicting with other
  DHCP clients.

## What I Learned / Troubleshooting

- **Recurring NETLOGON Event ID 5781 warnings.** Traced this to a DNS
  registration issue for the DC's SRV records. Fixed by verifying only one
  active NIC was registering in DNS, running `ipconfig /registerdns`, and
  confirming clean output from `dcdiag /test:dns`.
- **DHCP pool vs. reserved client IP.** Initially the DHCP pool's starting
  address overlapped with PC01's intended static IP. Rather than hard-code
  a static IP on the client (which DHCP wouldn't know about and could
  still hand out to someone else), I set up a proper DHCP reservation tied
  to PC01's MAC address — the correct fix, and a good example of
  reservations vs. exclusions vs. static configuration.
- **Fine-grained password policy vs. domain-wide GPO.** Realized that
  password/lockout policy can only be delegated per-OU using **Fine-Grained
  Password Policies (PSOs)** — a regular GPO linked to an OU is silently
  ignored for these settings. Since the lab asked for one policy for the
  whole domain, this was fine linked at the domain root, but it's the
  reason a bigger version of this project (see below) uses PSOs instead.

## Screenshots

See [`/screenshots`](screenshots) for the full walkthrough: Server Manager
overview, AD Users and Computers per OU, Group Policy Management Console,
and DHCP console.

## Technologies

- Windows Server 2025 (Standard, Evaluation)
- Active Directory Domain Services (AD DS)
- Group Policy Management (GPMC)
- DHCP Server role
- Windows 10/11 client
- VMware Workstation

## Roadmap — Bigger Version (in progress)

This lab is the foundation for a larger project I'm building to go deeper
into enterprise AD administration:

- [ ] Second domain controller + replication (DFSR/SYSVOL, Sites & Services)
- [ ] Full environment build automated with PowerShell (`New-ADUser`,
      `New-GPO`, `New-DhcpServerv4Scope`, etc. — see [`/scripts`](scripts))
- [ ] File server with NTFS + share permissions, DFS Namespace, folder
      redirection GPO
- [ ] Fine-Grained Password Policies (PSOs) per department instead of one
      domain-wide policy
- [ ] LAPS (Local Administrator Password Solution) replacing the static
      `itadmin` local admin account
- [ ] AD Certificate Services (lightweight internal PKI)
- [ ] Linux client joined to the domain via SSSD/realmd
- [ ] Centralized logging via Windows Event Forwarding

---

*Lab based on a self-assigned exam scenario. All usernames, IPs, and
domain names are lab-only and not tied to any real organization.*
