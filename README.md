# Advanced IAM PowerShell Automation Lab

## Overview

This repository contains five hands-on Identity and Access Management automation labs built with PowerShell and Microsoft Graph.

The project progresses from identity lifecycle automation through user and group administration, privileged-access review, RBAC drift detection, and a final identity security posture assessment.

Each lab demonstrates a practical IAM workflow using modular PowerShell scripts, Microsoft Entra ID data, structured baselines, logging, validation, and CSV reporting.

## Project Objectives

This project demonstrates how PowerShell automation can support:

- Joiner, mover, and leaver identity processes
- Microsoft Entra user and group administration
- Privileged-role visibility and review
- Role-based access control governance
- Expected-versus-actual access comparisons
- Authentication-method assessment
- Disabled-account and guest-access analysis
- Service-account governance
- Identity security reporting
- Repeatable and auditable IAM operations

## Labs

| Lab | Focus | Description |
|---|---|---|
| [Lab 01 – JML Lifecycle Automation](Lab-01-JML-Lifecycle-Automation/) | Identity lifecycle | Automates joiner, mover, and leaver processes for Microsoft Entra identities. |
| [Lab 02 – Entra User and Group Automation](Lab-02-Entra-User-Group-Automation/) | Identity administration | Automates Microsoft Entra user creation, group management, and membership operations. |
| [Lab 03 – Privileged Access Review](Lab-03-Privileged-Access-Review/) | Privileged access | Reviews Microsoft Entra role assignments and identifies identities with elevated access. |
| [Lab 04 – RBAC Drift Detection](Lab-04-RBAC-Drift-Detection/) | Access governance | Compares approved RBAC baselines with actual group memberships to detect missing and unexpected access. |
| [Lab 05 – Identity Security Posture Assessment](Lab-05-Identity-Security-Posture-Assessment/) | Identity security | Combines privileged access, RBAC, authentication, account hygiene, and service-account checks into a single assessment. |

## Repository Structure

```text
Advanced-IAM-PowerShell-Automation-Lab/
│
├── Lab-01-JML-Lifecycle-Automation/
├── Lab-02-Entra-User-Group-Automation/
├── Lab-03-Privileged-Access-Review/
├── Lab-04-RBAC-Drift-Detection/
├── Lab-05-Identity-Security-Posture-Assessment/
│
└── README.md
```

Each lab contains its own documentation, PowerShell scripts, configuration or baseline data, generated reports, logs, and supporting screenshots.

## Lab Progression

### Lab 01 – JML Lifecycle Automation

Lab 01 introduces identity lifecycle management through joiner, mover, and leaver workflows.

The automation demonstrates how standardized identity processes can support:

- User onboarding
- Identity updates
- Access changes
- Account offboarding
- Consistent lifecycle records
- Repeatable administrative operations

### Lab 02 – Entra User and Group Automation

Lab 02 focuses on automating common Microsoft Entra ID administration tasks.

The lab demonstrates:

- User account management
- Group creation and administration
- Group membership automation
- Input validation
- Structured processing
- Administrative reporting

### Lab 03 – Privileged Access Review

Lab 03 introduces privileged-access governance.

The lab reviews Microsoft Entra role assignments and helps identify:

- Privileged identities
- Users holding multiple elevated roles
- Role-assignment concentration
- Access requiring administrative review

### Lab 04 – RBAC Drift Detection

Lab 04 compares approved access with actual Microsoft Entra group memberships.

The lab detects:

- Missing expected access
- Unexpected group membership
- Incorrect role-based access
- Differences between approved and current access

The results provide a repeatable method for reviewing RBAC compliance.

### Lab 05 – Identity Security Posture Assessment

Lab 05 is the capstone assessment and combines the concepts developed throughout the project.

The assessment evaluates:

- Multiple privileged-role assignments
- RBAC drift
- Missing strong authentication methods
- Disabled accounts retaining access
- Guest accounts with sensitive access
- Service accounts with unapproved groups
- Service accounts with privileged roles

The lab produces color-coded console results, detailed CSV reports, a consolidated findings report, and an overall identity security posture rating.

## Technologies

The project uses:

- PowerShell
- Microsoft Graph PowerShell
- Microsoft Graph API
- Microsoft Entra ID
- CSV configuration and baseline files
- Modular PowerShell functions
- Structured logging
- Automated report generation
- Git and GitHub

## Microsoft Graph

The labs use delegated Microsoft Graph permissions according to the operations performed by each script.

Permissions used throughout the project include:

```text
User.Read.All
User.ReadWrite.All
Group.Read.All
Group.ReadWrite.All
Directory.Read.All
RoleManagement.Read.Directory
UserAuthenticationMethod.Read.All
```

## Reports and Evidence

Depending on the lab, generated evidence includes:

- Execution logs
- User-processing results
- Group-membership reports
- Privileged-access findings
- RBAC drift findings
- Authentication findings
- Account-hygiene findings
- Service-account findings
- Consolidated identity-security findings
- Posture summaries
- Screenshots of completed lab runs

Generated results are stored inside each lab’s designated `logs`, `reports`, or `screenshots` folders.

## Security Practices

The labs follow these security practices:

- Use only the Microsoft Graph permissions required for the task.
- Avoid storing passwords, tokens, or client secrets in scripts.
- Keep tenant-specific test data controlled.
- Validate CSV input before processing.
- Record automation activity in log files.
- Use assessment scopes to limit audit populations.
- Separate baseline data from processing logic.
- Use read-only permissions for assessment operations.
- Disconnect Graph sessions created by completed scripts.
- Review generated files before publishing tenant information.

## Skills Demonstrated

This project demonstrates experience with:

- IAM lifecycle automation
- Microsoft Entra ID administration
- PowerShell scripting
- Microsoft Graph integration
- Modular automation design
- User and group management
- Privileged-access analysis
- RBAC governance
- Authentication security
- Guest-account review
- Disabled-account analysis
- Service-account governance
- Error handling and validation
- Structured logging
- CSV data processing
- Security reporting
- Risk classification
- Technical documentation

## Author

Nikolas Caban
