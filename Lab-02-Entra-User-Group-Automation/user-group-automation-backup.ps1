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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$LogDirectory = Join-Path $PSScriptRoot "logs"
$ReportDirectory = Join-Path $PSScriptRoot "reports"

$LogPath = Join-Path $LogDirectory "user-group-automation.log"
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

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] $Message"

    Add-Content -Path $LogPath -Value $LogEntry

    switch ($Level) {
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        default   { Write-Host $LogEntry }
    }
}

function Add-ReportRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [string]$ObjectName,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Details
    )

    $Script:ReportResults.Add(
        [PSCustomObject]@{
            Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ObjectType = $ObjectType
            ObjectName = $ObjectName
            Action     = $Action
            Status     = $Status
            Details    = $Details
        }
    )
}

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

function Connect-ToMicrosoftGraph {
    [CmdletBinding()]
    param()

    $RequiredScopes = @(
        "User.ReadWrite.All"
        "Group.ReadWrite.All"
    )

    Write-Log -Message "Connecting to Microsoft Graph."

    Connect-MgGraph `
        -Scopes $RequiredScopes `
        -UseDeviceCode `
        -NoWelcome

    $Context = Get-MgContext

    if (-not $Context) {
        throw "Microsoft Graph authentication failed."
    }

    Write-Log `
        -Message "Connected to Microsoft Graph as $($Context.Account)." `
        -Level "SUCCESS"
}
# ------------------------------------------------------------
# User-management functions
# ------------------------------------------------------------

function Get-EntraUserByUpn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserPrincipalName
    )

    try {
        return Get-MgUser `
            -UserId $UserPrincipalName `
            -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle `
            -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match "Request_ResourceNotFound|404|does not exist") {
            return $null
        }

        throw
    }
}

function New-EntraUserFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    if ($ExistingUser) {
        $Message = "User already exists: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    $PasswordProfile = @{
        Password                      = "IAMLab2026!"
        ForceChangePasswordNextSignIn = $true
    }

    try {
        $NewUser = New-MgUser `
            -AccountEnabled:$true `
            -DisplayName $UserAction.DisplayName `
            -UserPrincipalName $UserAction.UserPrincipalName `
            -MailNickname $UserAction.MailNickname `
            -Department $UserAction.Department `
            -JobTitle $UserAction.JobTitle `
            -UsageLocation $UserAction.UsageLocation `
            -PasswordProfile $PasswordProfile

        $Message = "Created user: $($NewUser.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to create $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Failed" `
            -Details $Message
    }
}

function Update-EntraUserFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    if (-not $ExistingUser) {
        $Message = "Cannot update user because the account was not found: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        Update-MgUser `
            -UserId $ExistingUser.Id `
            -DisplayName $UserAction.DisplayName `
            -Department $UserAction.Department `
            -JobTitle $UserAction.JobTitle `
            -UsageLocation $UserAction.UsageLocation

        $Message = "Updated user attributes for $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to update $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Failed" `
            -Details $Message
    }
}

function Set-EntraUserEnabledState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction,

        [Parameter(Mandatory)]
        [bool]$AccountEnabled
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    $ActionName = if ($AccountEnabled) {
        "Enable"
    }
    else {
        "Disable"
    }

    if (-not $ExistingUser) {
        $Message = "Cannot $($ActionName.ToLower()) user because the account was not found: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Skipped" `
            -Details $Message

        return
    }

    if ($ExistingUser.AccountEnabled -eq $AccountEnabled) {
        $CurrentStatus = if ($AccountEnabled) {
            "enabled"
        }
        else {
            "disabled"
        }

        $Message = "User is already $CurrentStatus`: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        Update-MgUser `
            -UserId $ExistingUser.Id `
            -AccountEnabled:$AccountEnabled

        $Message = "$ActionName completed for $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to $($ActionName.ToLower()) $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Failed" `
            -Details $Message
    }
}

function Invoke-UserActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$UserActions
    )

    Write-Log -Message "Beginning user-action processing."

    foreach ($UserAction in $UserActions) {
        $Action = $UserAction.Action.Trim()

        Write-Log -Message "Processing user action '$Action' for $($UserAction.DisplayName)."

        switch ($Action.ToLower()) {
            "create" {
                New-EntraUserFromCsv -UserAction $UserAction
            }

            "update" {
                Update-EntraUserFromCsv -UserAction $UserAction
            }

            "enable" {
                Set-EntraUserEnabledState `
                    -UserAction $UserAction `
                    -AccountEnabled $true
            }

            "disable" {
                Set-EntraUserEnabledState `
                    -UserAction $UserAction `
                    -AccountEnabled $false
            }

            default {
                $Message = "Unsupported user action '$Action' for $($UserAction.DisplayName)."

                Write-Log -Message $Message -Level "WARNING"

                Add-ReportRecord `
                    -ObjectType "User" `
                    -ObjectName $UserAction.DisplayName `
                    -Action $Action `
                    -Status "Skipped" `
                    -Details $Message
            }
        }
    }

    Write-Log -Message "Finished user-action processing."
}# ------------------------------------------------------------
# Group-management functions
# ------------------------------------------------------------

function Get-EntraGroupByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName
    )

    # Escape apostrophes so the value can be safely used in an OData filter.
    $EscapedGroupName = $GroupName.Replace("'", "''")

    $Groups = @(
        Get-MgGroup `
            -Filter "displayName eq '$EscapedGroupName'" `
            -Property Id,DisplayName,Description,MailNickname,SecurityEnabled,GroupTypes `
            -All
    )

    if ($Groups.Count -eq 0) {
        return $null
    }

    if ($Groups.Count -gt 1) {
        throw "Multiple groups were found with the display name '$GroupName'. Group names must be unique for this lab."
    }

    return $Groups[0]
}

function New-EntraGroupFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GroupAction
    )

    $ExistingGroup = Get-EntraGroupByName `
        -GroupName $GroupAction.GroupName

    if ($ExistingGroup) {
        $Message = "Group already exists: $($GroupAction.GroupName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "Group" `
            -ObjectName $GroupAction.GroupName `
            -Action "Create" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    # Create a valid mail nickname from the display name.
    $MailNickname = (
        $GroupAction.GroupName `
            -replace "[^a-zA-Z0-9]", ""
    ).ToLower()

    try {
        $NewGroup = New-MgGroup `
            -DisplayName $GroupAction.GroupName `
            -Description $GroupAction.Description `
            -MailEnabled:$false `
            -MailNickname $MailNickname `
            -SecurityEnabled:$true `
            -GroupTypes @()

        $Message = "Created security group: $($NewGroup.DisplayName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "Group" `
            -ObjectName $GroupAction.GroupName `
            -Action "Create" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to create group $($GroupAction.GroupName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "Group" `
            -ObjectName $GroupAction.GroupName `
            -Action "Create" `
            -Status "Failed" `
            -Details $Message
    }
}

function Add-EntraGroupMemberFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GroupAction
    )

    $Group = Get-EntraGroupByName `
        -GroupName $GroupAction.GroupName

    if (-not $Group) {
        $Message = "Cannot add member because the group was not found: $($GroupAction.GroupName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "AddMember" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    $User = Get-EntraUserByUpn `
        -UserPrincipalName $GroupAction.MemberUserPrincipalName

    if (-not $User) {
        $Message = "Cannot add member because the user was not found: $($GroupAction.MemberUserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "AddMember" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        $ExistingMemberIds = @(
            Get-MgGroupMember `
                -GroupId $Group.Id `
                -All |
            Select-Object -ExpandProperty Id
        )

        if ($ExistingMemberIds -contains $User.Id) {
            $Message = "$($User.UserPrincipalName) is already a member of $($Group.DisplayName)"

            Write-Log -Message $Message -Level "WARNING"

            Add-ReportRecord `
                -ObjectType "Group Membership" `
                -ObjectName $Group.DisplayName `
                -Action "AddMember" `
                -Status "Skipped" `
                -Details $Message

            return
        }

        $BodyParameter = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($User.Id)"
        }

        New-MgGroupMemberByRef `
            -GroupId $Group.Id `
            -BodyParameter $BodyParameter

        $Message = "Added $($User.UserPrincipalName) to $($Group.DisplayName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $Group.DisplayName `
            -Action "AddMember" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to add $($GroupAction.MemberUserPrincipalName) to $($GroupAction.GroupName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "AddMember" `
            -Status "Failed" `
            -Details $Message
    }
}

function Remove-EntraGroupMemberFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$GroupAction
    )

    $Group = Get-EntraGroupByName `
        -GroupName $GroupAction.GroupName

    if (-not $Group) {
        $Message = "Cannot remove member because the group was not found: $($GroupAction.GroupName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "RemoveMember" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    $User = Get-EntraUserByUpn `
        -UserPrincipalName $GroupAction.MemberUserPrincipalName

    if (-not $User) {
        $Message = "Cannot remove member because the user was not found: $($GroupAction.MemberUserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "RemoveMember" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        $ExistingMemberIds = @(
            Get-MgGroupMember `
                -GroupId $Group.Id `
                -All |
            Select-Object -ExpandProperty Id
        )

        if ($ExistingMemberIds -notcontains $User.Id) {
            $Message = "$($User.UserPrincipalName) is not currently a member of $($Group.DisplayName)"

            Write-Log -Message $Message -Level "WARNING"

            Add-ReportRecord `
                -ObjectType "Group Membership" `
                -ObjectName $Group.DisplayName `
                -Action "RemoveMember" `
                -Status "Skipped" `
                -Details $Message

            return
        }

        Remove-MgGroupMemberByRef `
            -GroupId $Group.Id `
            -DirectoryObjectId $User.Id

        $Message = "Removed $($User.UserPrincipalName) from $($Group.DisplayName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $Group.DisplayName `
            -Action "RemoveMember" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to remove $($GroupAction.MemberUserPrincipalName) from $($GroupAction.GroupName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "Group Membership" `
            -ObjectName $GroupAction.GroupName `
            -Action "RemoveMember" `
            -Status "Failed" `
            -Details $Message
    }
}

function Invoke-GroupActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$GroupActions
    )

    Write-Log -Message "Beginning group-action processing."

    foreach ($GroupAction in $GroupActions) {
        $Action = $GroupAction.Action.Trim()

        Write-Log -Message "Processing group action '$Action' for $($GroupAction.GroupName)."

        switch ($Action.ToLower()) {
            "create" {
                New-EntraGroupFromCsv -GroupAction $GroupAction
            }

            "addmember" {
                Add-EntraGroupMemberFromCsv -GroupAction $GroupAction
            }

            "removemember" {
                Remove-EntraGroupMemberFromCsv -GroupAction $GroupAction
            }

            default {
                $Message = "Unsupported group action '$Action' for $($GroupAction.GroupName)."

                Write-Log -Message $Message -Level "WARNING"

                Add-ReportRecord `
                    -ObjectType "Group" `
                    -ObjectName $GroupAction.GroupName `
                    -Action $Action `
                    -Status "Skipped" `
                    -Details $Message
            }
        }
    }

    Write-Log -Message "Finished group-action processing."
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
Invoke-UserActions -UserActions $UserActions
    Write-Log -Message "Imported $($UserActions.Count) user actions."
    Write-Log -Message "Imported $($GroupActions.Count) group actions."

    
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