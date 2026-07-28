# # Lab 03 – Privileged Access Review

## Overview

This lab demonstrates how to automate privileged access reviews in Microsoft Entra ID using Microsoft Graph PowerShell.

The script connects to Microsoft Graph, audits privileged directory role assignments, identifies common IAM security risks, exports audit reports, and generates an executive summary suitable for administrators and security teams.

## Features

- Authenticate to Microsoft Graph
- Retrieve active Microsoft Entra directory roles
- Enumerate privileged role assignments
- Detect users with multiple privileged role assignments
- Detect disabled privileged accounts
- Detect guest accounts assigned privileged roles
- Generate timestamped CSV audit reports
- Generate timestamped execution logs
- Display an executive summary with overall risk level

## Technologies Used

- PowerShell 7
- Microsoft Graph PowerShell SDK
- Microsoft Entra ID
- Microsoft Graph API

## Project Structure

```text
Lab-03-Privileged-Access-Review
│
├── modules
│   ├── GraphConnection.ps1
│   ├── Logging.ps1
│   ├── Reporting.ps1
│   └── RoleAudit.ps1
│
├── logs
├── reports
├── screenshots
│
├── privileged-access-review.ps1
└── README.md
```

## Security Checks Performed

The script performs the following privileged access checks:

- Multiple privileged role assignments
- Disabled privileged accounts
- Guest accounts with privileged roles

## Screenshots

### Privileged Access Review Summary

The executive summary displays the number of active roles, privileged assignments, detected findings, and the overall risk level.

![Privileged Access Review Summary](screenshots/privileged-access-summary.png)

### Reports Created

The script displays the file paths of the CSV reports generated during execution.

![Reports Created](screenshots/reports-created.png)

### Reports Folder

The reports folder contains timestamped role-assignment and privileged-access findings reports.

![Reports Folder](screenshots/reports-folder.png)

### Privileged Role Assignments Report

The role-assignment CSV contains the privileged users, user principal names, and assigned Microsoft Entra roles discovered during the audit.

![Privileged Role Assignments Report](screenshots/role-assignments-report.png)

## Generated Reports

The script exports two timestamped CSV reports during each execution.

| Report | Description |
|---|---|
| `PrivilegedRoleAssignments` | Complete list of discovered privileged role assignments |
| `PrivilegedAccessFindings` | Security findings identified during the privileged access review |


## Learning Objectives

This lab demonstrates practical IAM skills including:

- Microsoft Graph authentication
- Microsoft Entra role auditing
- Privileged access analysis
- Excessive privilege detection
- PowerShell modularization
- Error handling
- Operational logging
- CSV report generation
- Risk-summary creation

  ## Author

Nikolas Caban
