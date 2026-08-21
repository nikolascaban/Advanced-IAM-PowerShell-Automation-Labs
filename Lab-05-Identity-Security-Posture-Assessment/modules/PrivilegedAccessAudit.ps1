function Get-PrivilegedAccessFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$AssessmentScope
    )

    Write-LabLog -Message 'Starting privileged-access audit.'

    try {
        $roleAssignments = @(
            Get-MgRoleManagementDirectoryRoleAssignment `
                -All `
                -ExpandProperty 'roleDefinition' `
                -ErrorAction Stop
        )

        $findings = foreach ($identity in $AssessmentScope) {
            try {
                $user = Get-MgUser `
                    -UserId $identity.UserPrincipalName `
                    -Property Id, DisplayName, UserPrincipalName `
                    -ErrorAction Stop

                $assignedRoles = @(
                    $roleAssignments |
                        Where-Object PrincipalId -EQ $user.Id |
                        ForEach-Object { $_.RoleDefinition.DisplayName } |
                        Where-Object { $_ } |
                        Sort-Object -Unique
                )

                Write-LabLog -Message (
                    '{0} has {1} active role assignment(s).' -f
                    $user.UserPrincipalName,
                    $assignedRoles.Count
                )

                if ($assignedRoles.Count -ge 2) {
                    [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        DisplayName       = $user.DisplayName
                        FindingType       = 'Multiple Privileged Roles'
                        RoleCount         = $assignedRoles.Count
                        Roles             = $assignedRoles -join '; '
                        Severity          = 'Medium'
                        Details           = 'Identity holds multiple active Entra role assignments.'
                    }
                }
            }
            catch {
                Write-LabLog `
                    -Message "Could not assess $($identity.UserPrincipalName): $($_.Exception.Message)" `
                    -Level WARNING
            }
        }

        Write-LabLog -Message "Privileged-access audit found $(@($findings).Count) finding(s)."
        return @($findings)
    }
    catch {
        Write-LabLog `
            -Message "Privileged-access audit failed: $($_.Exception.Message)" `
            -Level ERROR

        throw
    }
}
function Show-PrivilegedAccessFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Findings
    )

    if ($Findings.Count -eq 0) {
        Write-Host 'No privileged-access findings detected.' -ForegroundColor Green
        return
    }

    $format = '{0,-52} {1,-30} {2,-10} {3,-10} {4}'

    Write-Host (
        $format -f
        'UserPrincipalName',
        'FindingType',
        'RoleCount',
        'Severity',
        'Roles'
    ) -ForegroundColor Cyan

    Write-Host ('-' * 150) -ForegroundColor DarkGray

    foreach ($finding in $Findings) {
        $color = switch ($finding.Severity) {
            'High'   { 'Red' }
            'Medium' { 'Yellow' }
            'Low'    { 'Green' }
            default  { 'White' }
        }

        Write-Host (
            $format -f
            $finding.UserPrincipalName,
            $finding.FindingType,
            $finding.RoleCount,
            $finding.Severity,
            $finding.Roles
        ) -ForegroundColor $color
    }
}