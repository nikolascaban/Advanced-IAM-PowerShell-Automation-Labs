function Export-RBACDriftReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ComparisonResults,

        [Parameter(Mandatory)]
        [string]$ReportDirectory
    )

    try {
        Write-Log -Message "Exporting the RBAC drift report..."

        if (-not (Test-Path -Path $ReportDirectory)) {
            New-Item `
                -Path $ReportDirectory `
                -ItemType Directory `
                -Force | Out-Null
        }

        $Timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

        $ReportPath = Join-Path `
            -Path $ReportDirectory `
            -ChildPath "RBACDriftReport-$Timestamp.csv"

        $ComparisonResults |
            Export-Csv `
                -Path $ReportPath `
                -NoTypeInformation

        Write-Log `
            -Message "RBAC drift report exported to $ReportPath" `
            -Level "SUCCESS"

        return $ReportPath
    }
    catch {
        Write-Log `
            -Message "Failed to export the RBAC drift report: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}
function Show-RBACDriftSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$ComparisonResults
    )

    $UsersAudited = $ComparisonResults.Count

    $CompliantUsers = @(
        $ComparisonResults |
            Where-Object ComplianceStatus -eq "Compliant"
    ).Count

    $DriftedUsers = @(
        $ComparisonResults |
            Where-Object ComplianceStatus -eq "Drift Detected"
    ).Count

    $MissingMemberships = @(
        $ComparisonResults |
            Where-Object { $_.MissingGroups }
    ).Count

    $UnexpectedMemberships = @(
        $ComparisonResults |
            Where-Object { $_.UnexpectedGroups }
    ).Count

    if ($UsersAudited -gt 0) {
        $CompliancePercentage = [math]::Round(
            ($CompliantUsers / $UsersAudited) * 100,
            2
        )
    }
    else {
        $CompliancePercentage = 0
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "          RBAC DRIFT SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Users Audited:               $UsersAudited"
    Write-Host "Compliant Users:             $CompliantUsers" -ForegroundColor Green
    Write-Host "Users with Drift:            $DriftedUsers" -ForegroundColor Yellow
    Write-Host "Missing Membership Findings: $MissingMemberships" -ForegroundColor Yellow
    Write-Host "Unexpected Access Findings:  $UnexpectedMemberships" -ForegroundColor Red
    Write-Host "Compliance Percentage:       $CompliancePercentage%"
    Write-Host "========================================" -ForegroundColor Cyan
}