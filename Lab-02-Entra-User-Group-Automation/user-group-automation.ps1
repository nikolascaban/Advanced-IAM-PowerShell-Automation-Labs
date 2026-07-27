#Requires -Version 7.0

<#
.SYNOPSIS
    Automates Microsoft Entra user and security-group administration.

.DESCRIPTION
    Reads user and group actions from CSV files and performs authorized
    Microsoft Entra operations through the Microsoft Graph PowerShell SDK.

    Supported user actions:
    - Create
    - Update
    - Enable
    - Disable

    Supported group actions:
    - Create
    - AddMember
    - RemoveMember

.NOTES
    Project: Advanced IAM PowerShell Automation Labs
    Lab: Lab 02 - Entra User & Group Automation
    Author: Nikolas Caban
#>

[CmdletBinding()]
param(
    [string]$UsersCsvPath = "$PSScriptRoot\users.csv",
    [string]$GroupsCsvPath = "$PSScriptRoot\groups.csv"
)
# ------------------------------------------------------------
# Load supporting scripts
# ------------------------------------------------------------

$ModuleFiles = @(
    "Logging.ps1"
    "Reporting.ps1"
    "GraphConnection.ps1"
    "UserManagement.ps1"
    "GroupManagement.ps1"
)

foreach ($ModuleFile in $ModuleFiles) {
    $ModulePath = Join-Path $PSScriptRoot "modules\$ModuleFile"

    if (-not (Test-Path $ModulePath -PathType Leaf)) {
        throw "Required module file was not found: $ModulePath"
    }

    . $ModulePath
}
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$LogDirectory = Join-Path $PSScriptRoot "logs"
$ReportDirectory = Join-Path $PSScriptRoot "reports"

$ReportPath = Join-Path $ReportDirectory "user-group-automation-report.csv"

foreach ($Directory in @($LogDirectory, $ReportDirectory)) {
    if (-not (Test-Path $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force | Out-Null
    }
}

# Holds all report records generated during execution.
$Script:ReportResults = [System.Collections.Generic.List[object]]::new()

# ------------------------------------------------------------
# Logging and reporting
# ------------------------------------------------------------




# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

function Test-RequiredFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Required file was not found: $Path"
    }
}
# ------------------------------------------------------------
# Main execution
# ------------------------------------------------------------

try {
    Write-Log -Message "Starting Lab 02 Entra user and group automation."

    Test-RequiredFile -Path $UsersCsvPath
    Test-RequiredFile -Path $GroupsCsvPath

    Connect-ToMicrosoftGraph

$UserActions = Import-Csv -Path $UsersCsvPath
$GroupActions = Import-Csv -Path $GroupsCsvPath

Write-Log -Message "Imported $($UserActions.Count) user actions."
Write-Log -Message "Imported $($GroupActions.Count) group actions."

Invoke-UserActions -UserActions $UserActions
Invoke-GroupActions -GroupActions $GroupActions
    
}
catch {
    Write-Log -Message $_.Exception.Message -Level "ERROR"
    throw
}
finally {
    if ($Script:ReportResults.Count -gt 0) {
        $Script:ReportResults |
            Export-Csv -Path $ReportPath -NoTypeInformation
    }

    Write-Log -Message "Lab 02 execution finished."
}