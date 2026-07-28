function Get-DirectoryRoles {
    [CmdletBinding()]
    param()

    try {
        Write-Log -Message "Retrieving Microsoft Entra directory roles..."

        $roles = Get-MgDirectoryRole | Sort-Object DisplayName

        Write-Log `
            -Message "Retrieved $($roles.Count) active directory roles." `
            -Level "SUCCESS"

        return $roles
    }
    catch {
        Write-Log `
            -Message "Failed to retrieve directory roles: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}
function Get-RoleAssignments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Roles
    )

    try {
        Write-Log -Message "Retrieving directory role assignments..."

        $assignments = foreach ($role in $Roles) {

            $members = Get-MgDirectoryRoleMember `
                -DirectoryRoleId $role.Id -All

            foreach ($member in $members) {

                $user = Get-MgUser -UserId $member.Id

                [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Role = $role.DisplayName
                    AccountEnabled = $user.AccountEnabled
                    UserType = $user.UserType
                }
            }
        }

        Write-Log `
            -Message "Retrieved $($assignments.Count) privileged role assignments." `
            -Level "SUCCESS"

        return $assignments
    }
    catch {
        Write-Log `
            -Message "Failed to retrieve role assignments: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}
function Find-MultiplePrivilegedRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Assignments
    )

    Write-Log -Message "Checking for users with multiple privileged roles..."

    $findings = $Assignments |
        Group-Object UserPrincipalName |
        Where-Object Count -gt 1 |
        ForEach-Object {
            $userAssignments = $_.Group

            [PSCustomObject]@{
                DisplayName       = $userAssignments[0].DisplayName
                UserPrincipalName = $userAssignments[0].UserPrincipalName
                RiskLevel         = "Medium"
                Finding           = "Multiple Privileged Roles"
                RoleCount         = $_.Count
                Roles             = ($userAssignments.Role -join "; ")
            }
        }

    Write-Log `
        -Message "Found $($findings.Count) users with multiple privileged roles." `
        -Level "SUCCESS"

    return $findings
}
function Find-DisabledPrivilegedAccounts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Assignments
    )

    Write-Log -Message "Checking for disabled privileged accounts..."

    $findings = $Assignments |
        Where-Object { $_.AccountEnabled -eq $false } |
        ForEach-Object {
            [PSCustomObject]@{
                DisplayName       = $_.DisplayName
                UserPrincipalName = $_.UserPrincipalName
                RiskLevel         = "High"
                Finding           = "Disabled Privileged Account"
                RoleCount         = 1
                Roles             = $_.Role
            }
        }

    Write-Log `
        -Message "Found $($findings.Count) disabled privileged account assignments." `
        -Level "SUCCESS"

    return $findings
}

function Find-GuestPrivilegedAccounts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Assignments
    )

    Write-Log -Message "Checking for guest accounts with privileged roles..."

    $findings = $Assignments |
        Where-Object { $_.UserType -eq "Guest" } |
        ForEach-Object {
            [PSCustomObject]@{
                DisplayName       = $_.DisplayName
                UserPrincipalName = $_.UserPrincipalName
                RiskLevel         = "High"
                Finding           = "Guest Privileged Account"
                RoleCount         = 1
                Roles             = $_.Role
            }
        }

    Write-Log `
        -Message "Found $($findings.Count) guest privileged account assignments." `
        -Level "SUCCESS"

    return $findings
}