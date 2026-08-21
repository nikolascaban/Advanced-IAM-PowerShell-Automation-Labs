function Export-AssessmentReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$PrivilegedFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$RBACFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$AuthenticationFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$AccountHygieneFindings,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$ServiceAccountFindings,

        [Parameter(Mandatory)]
        [int]$IdentitiesAudited,

        [Parameter(Mandatory)]
        [string]$ReportDirectory
    )

    if (-not (Test-Path $ReportDirectory)) {
        New-Item -Path $ReportDirectory -ItemType Directory -Force | Out-Null
    }

    $reportSets = @(
        @{
            Category = 'Privileged Access'
            File     = 'PrivilegedAccessFindings.csv'
            Findings = @($PrivilegedFindings)
        }
        @{
            Category = 'RBAC'
            File     = 'RBACFindings.csv'
            Findings = @($RBACFindings)
        }
        @{
            Category = 'Authentication'
            File     = 'AuthenticationFindings.csv'
            Findings = @($AuthenticationFindings)
        }
        @{
            Category = 'Account Hygiene'
            File     = 'AccountHygieneFindings.csv'
            Findings = @($AccountHygieneFindings)
        }
        @{
            Category = 'Service Accounts'
            File     = 'ServiceAccountFindings.csv'
            Findings = @($ServiceAccountFindings)
        }
    )

    $allFindings = foreach ($reportSet in $reportSets) {
        $categoryFindings = @($reportSet.Findings)

        if ($categoryFindings.Count -gt 0) {
            $categoryPath = Join-Path $ReportDirectory $reportSet.File

            $categoryFindings |
                Export-Csv -Path $categoryPath -NoTypeInformation

            Write-LabLog -Message "Exported $categoryPath."
        }

        foreach ($finding in $categoryFindings) {
            $access = if ($finding.Roles) {
                $finding.Roles
            }
            elseif ($finding.GroupName) {
                $finding.GroupName
            }
            elseif ($finding.MethodsDetected) {
                $finding.MethodsDetected
            }
            elseif ($finding.Access) {
                $finding.Access
            }
            else {
                ''
            }

            [PSCustomObject]@{
                Category          = $reportSet.Category
                UserPrincipalName = $finding.UserPrincipalName
                FindingType       = $finding.FindingType
                Access            = $access
                Severity          = $finding.Severity
                Details           = $finding.Details
            }
        }
    }

    $allFindings = @($allFindings)

    $highCount = @(
        $allFindings | Where-Object Severity -EQ 'High'
    ).Count

    $mediumCount = @(
        $allFindings | Where-Object Severity -EQ 'Medium'
    ).Count

    $lowCount = @(
        $allFindings | Where-Object Severity -EQ 'Low'
    ).Count

    $overallPosture = if ($highCount -gt 0) {
        'HIGH'
    }
    elseif ($mediumCount -gt 0) {
        'MEDIUM'
    }
    else {
        'LOW'
    }

    $summary = [PSCustomObject]@{
        AssessmentDate          = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        IdentitiesAudited       = $IdentitiesAudited
        TotalFindings           = $allFindings.Count
        PrivilegedFindings      = @($PrivilegedFindings).Count
        RBACFindings            = @($RBACFindings).Count
        AuthenticationFindings  = @($AuthenticationFindings).Count
        AccountHygieneFindings  = @($AccountHygieneFindings).Count
        ServiceAccountFindings  = @($ServiceAccountFindings).Count
        HighRiskFindings        = $highCount
        MediumRiskFindings      = $mediumCount
        LowRiskFindings         = $lowCount
        OverallPosture          = $overallPosture
    }

    if ($allFindings.Count -gt 0) {
        $allFindings |
            Export-Csv `
                -Path (Join-Path $ReportDirectory 'IdentitySecurityFindings.csv') `
                -NoTypeInformation
    }

    $summary |
        Export-Csv `
            -Path (Join-Path $ReportDirectory 'PostureSummary.csv') `
            -NoTypeInformation

    Write-LabLog -Message "Reporting complete. Overall posture: $overallPosture."

    return [PSCustomObject]@{
        Summary     = $summary
        AllFindings = $allFindings
    }
}

function Show-PostureSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Summary
    )

    Write-Host ''
    Write-Host '==========================================' -ForegroundColor Cyan
    Write-Host ' Identity Security Posture Assessment' -ForegroundColor Cyan
    Write-Host '==========================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host "Identities audited:        $($Summary.IdentitiesAudited)"
    Write-Host "Total findings:            $($Summary.TotalFindings)"
    Write-Host "Privileged findings:       $($Summary.PrivilegedFindings)"
    Write-Host "RBAC findings:             $($Summary.RBACFindings)"
    Write-Host "Authentication findings:   $($Summary.AuthenticationFindings)"
    Write-Host "Account hygiene findings:  $($Summary.AccountHygieneFindings)"
    Write-Host "Service account findings:  $($Summary.ServiceAccountFindings)"
    Write-Host ''
    Write-Host "High-risk findings:        $($Summary.HighRiskFindings)" -ForegroundColor Red
    Write-Host "Medium-risk findings:      $($Summary.MediumRiskFindings)" -ForegroundColor Yellow
    Write-Host "Low-risk findings:         $($Summary.LowRiskFindings)" -ForegroundColor Green
    Write-Host ''

    $postureColor = switch ($Summary.OverallPosture) {
        'HIGH'   { 'Red' }
        'MEDIUM' { 'Yellow' }
        default  { 'Green' }
    }

    Write-Host "Overall posture: $($Summary.OverallPosture)" `
        -ForegroundColor $postureColor
}