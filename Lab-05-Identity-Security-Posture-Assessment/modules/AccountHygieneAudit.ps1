function Get-AccountHygieneFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$AssessmentScope,

        [Parameter(Mandatory)]
        [string[]]$SensitiveGroups
    )

    Write-LabLog -Message 'Starting account-hygiene audit.'

    $findings = foreach ($identity in $AssessmentScope) {
        $upn = $identity.UserPrincipalName

        try {
            $user = Get-MgUser `
                -UserId $upn `
                -Property Id, DisplayName, UserPrincipalName, AccountEnabled, UserType `
                -ErrorAction Stop

            $groupNames = @(
                Get-MgUserMemberOfAsGroup `
                    -UserId $user.Id `
                    -Property Id, DisplayName `
                    -All `
                    -ErrorAction Stop |
                    Select-Object -ExpandProperty DisplayName |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            if (-not $user.AccountEnabled -and $groupNames.Count -gt 0) {
                [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName       = $user.DisplayName
                    FindingType       = 'Disabled Account Retains Access'
                    Access            = $groupNames -join '; '
                    Severity          = 'High'
                    Details           = 'Disabled account still has direct group memberships.'
                }
            }

            $sensitiveAccess = @(
                $groupNames |
                    Where-Object { $_ -in $SensitiveGroups }
            )

            if ($user.UserType -eq 'Guest' -and $sensitiveAccess.Count -gt 0) {
                [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName       = $user.DisplayName
                    FindingType       = 'Guest Has Sensitive Access'
                    Access            = $sensitiveAccess -join '; '
                    Severity          = 'High'
                    Details           = 'Guest account has direct membership in a sensitive group.'
                }
            }

            Write-LabLog -Message (
                '{0}: enabled={1}, user type={2}, direct groups={3}.' -f
                $upn,
                $user.AccountEnabled,
                $user.UserType,
                $groupNames.Count
            )
        }
        catch {
            Write-LabLog `
                -Message "Could not audit account hygiene for ${upn}: $($_.Exception.Message)" `
                -Level WARNING
        }
    }

    Write-LabLog -Message "Account-hygiene audit found $(@($findings).Count) finding(s)."
    return @($findings)
}

function Show-AccountHygieneFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Findings
    )

    if ($Findings.Count -eq 0) {
        Write-Host 'No account-hygiene findings detected.' -ForegroundColor Green
        return
    }

    $format = '{0,-58} {1,-34} {2,-30} {3,-10} {4}'

    Write-Host (
        $format -f
        'UserPrincipalName',
        'FindingType',
        'Access',
        'Severity',
        'Details'
    ) -ForegroundColor Cyan

    Write-Host ('-' * 175) -ForegroundColor DarkGray

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