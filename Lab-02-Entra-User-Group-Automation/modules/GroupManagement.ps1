# ------------------------------------------------------------
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
