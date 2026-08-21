function Get-RBACFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$RBACBaseline
    )

    Write-LabLog -Message 'Starting RBAC audit.'

    $governedGroups = @(
        $RBACBaseline.ExpectedGroups |
            ForEach-Object { $_ -split ';' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )

    $findings = foreach ($baselineEntry in $RBACBaseline) {
        $upn = $baselineEntry.UserPrincipalName

        try {
            $expectedGroups = @(
                $baselineEntry.ExpectedGroups -split ';' |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            $actualGroups = @(
                Get-MgUserMemberOfAsGroup `
                    -UserId $upn `
                    -Property Id, DisplayName `
                    -All `
                    -ErrorAction Stop |
                    Select-Object -ExpandProperty DisplayName |
                    Where-Object { $_ -in $governedGroups } |
                    Sort-Object -Unique
            )

            $missingGroups = @(
                $expectedGroups |
                    Where-Object { $_ -notin $actualGroups }
            )

            $unexpectedGroups = @(
                $actualGroups |
                    Where-Object { $_ -notin $expectedGroups }
            )

            Write-LabLog -Message (
                '{0}: {1} missing and {2} unexpected governed group(s).' -f
                $upn,
                $missingGroups.Count,
                $unexpectedGroups.Count
            )

            foreach ($group in $missingGroups) {
                [PSCustomObject]@{
                    UserPrincipalName = $upn
                    FindingType       = 'Missing Expected Group'
                    GroupName         = $group
                    ExpectedAccess    = 'Assigned'
                    ActualAccess      = 'Not assigned'
                    Severity          = 'Medium'
                    Details           = "Expected membership in $group is missing."
                }
            }

            foreach ($group in $unexpectedGroups) {
                [PSCustomObject]@{
                    UserPrincipalName = $upn
                    FindingType       = 'Unexpected Group Membership'
                    GroupName         = $group
                    ExpectedAccess    = 'Not assigned'
                    ActualAccess      = 'Assigned'
                    Severity          = 'Medium'
                    Details           = "Unexpected membership in $group was detected."
                }
            }
        }
        catch {
            Write-LabLog `
                -Message "Could not audit RBAC for ${upn}: $($_.Exception.Message)" `
                -Level WARNING
        }
    }

    Write-LabLog -Message "RBAC audit found $(@($findings).Count) finding(s)."
    return @($findings)
}
function Show-RBACFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Findings
    )

    $format = '{0,-52} {1,-30} {2,-22} {3,-16} {4,-16} {5,-10} {6}'

    Write-Host (
        $format -f
        'UserPrincipalName',
        'FindingType',
        'GroupName',
        'ExpectedAccess',
        'ActualAccess',
        'Severity',
        'Details'
    ) -ForegroundColor Cyan

    Write-Host ('-' * 180) -ForegroundColor DarkGray

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
            $finding.GroupName,
            $finding.ExpectedAccess,
            $finding.ActualAccess,
            $finding.Severity,
            $finding.Details
        ) -ForegroundColor $color
    }
}