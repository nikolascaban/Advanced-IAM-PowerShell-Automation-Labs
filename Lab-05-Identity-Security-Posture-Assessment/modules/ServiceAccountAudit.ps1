function Get-ServiceAccountFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ServiceAccountBaseline
    )

    Write-LabLog -Message 'Starting service-account audit.'

    try {
        $roleAssignments = @(
            Get-MgRoleManagementDirectoryRoleAssignment `
                -All `
                -ExpandProperty 'roleDefinition' `
                -ErrorAction Stop
        )

        $findings = foreach ($account in $ServiceAccountBaseline) {
            $upn = $account.UserPrincipalName

            try {
                $user = Get-MgUser `
                    -UserId $upn `
                    -Property Id, DisplayName, UserPrincipalName, AccountEnabled `
                    -ErrorAction Stop

                $approvedGroups = @(
                    $account.ApprovedGroups -split ';' |
                        ForEach-Object { $_.Trim() } |
                        Where-Object { $_ } |
                        Sort-Object -Unique
                )

                $approvedRoles = @(
                    $account.ApprovedRoles -split ';' |
                        ForEach-Object { $_.Trim() } |
                        Where-Object { $_ } |
                        Sort-Object -Unique
                )

                $actualGroups = @(
                    Get-MgUserMemberOfAsGroup `
                        -UserId $user.Id `
                        -Property Id, DisplayName `
                        -All `
                        -ErrorAction Stop |
                        Select-Object -ExpandProperty DisplayName |
                        Where-Object { $_ } |
                        Sort-Object -Unique
                )

                $actualRoles = @(
                    $roleAssignments |
                        Where-Object PrincipalId -EQ $user.Id |
                        ForEach-Object { $_.RoleDefinition.DisplayName } |
                        Where-Object { $_ } |
                        Sort-Object -Unique
                )

                $unexpectedGroups = @(
                    $actualGroups |
                        Where-Object { $_ -notin $approvedGroups }
                )

                $unexpectedRoles = @(
                    $actualRoles |
                        Where-Object { $_ -notin $approvedRoles }
                )

                foreach ($group in $unexpectedGroups) {
                    [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        FindingType       = 'Unexpected Service Account Group'
                        Access            = $group
                        Severity          = 'Medium'
                        Details           = "Service account has unapproved membership in $group."
                    }
                }

                foreach ($role in $unexpectedRoles) {
                    [PSCustomObject]@{
                        UserPrincipalName = $user.UserPrincipalName
                        FindingType       = 'Privileged Service Account'
                        Access            = $role
                        Severity          = 'High'
                        Details           = "Service account has unapproved Entra role: $role."
                    }
                }

                Write-LabLog -Message (
                    '{0}: {1} unexpected group(s), {2} unexpected role(s).' -f
                    $upn,
                    $unexpectedGroups.Count,
                    $unexpectedRoles.Count
                )
            }
            catch {
                Write-LabLog `
                    -Message "Could not audit service account ${upn}: $($_.Exception.Message)" `
                    -Level WARNING
            }
        }

        Write-LabLog -Message "Service-account audit found $(@($findings).Count) finding(s)."
        return @($findings)
    }
    catch {
        Write-LabLog `
            -Message "Service-account audit failed: $($_.Exception.Message)" `
            -Level ERROR

        throw
    }
}

function Show-ServiceAccountFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Findings
    )

    if ($Findings.Count -eq 0) {
        Write-Host 'No service-account findings detected.' -ForegroundColor Green
        return
    }

    $format = '{0,-52} {1,-36} {2,-28} {3,-10} {4}'

    Write-Host (
        $format -f
        'UserPrincipalName',
        'FindingType',
        'Access',
        'Severity',
        'Details'
    ) -ForegroundColor Cyan

    Write-Host ('-' * 170) -ForegroundColor DarkGray

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
            $finding.Access,
            $finding.Severity,
            $finding.Details
        ) -ForegroundColor $color
    }
}