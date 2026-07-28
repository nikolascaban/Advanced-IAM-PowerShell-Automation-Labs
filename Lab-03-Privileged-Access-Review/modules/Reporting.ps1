function Export-PrivilegedAccessReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Assignments,

        [Parameter(Mandatory)]
        $Findings,

        [Parameter(Mandatory)]
        [string]$ReportDirectory
    )

    try {
        Write-Log -Message "Exporting privileged access reports..."

        if (-not (Test-Path $ReportDirectory)) {
            New-Item `
                -Path $ReportDirectory `
                -ItemType Directory `
                -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

        $assignmentReport = Join-Path `
            $ReportDirectory `
            "PrivilegedRoleAssignments-$timestamp.csv"

        $findingsReport = Join-Path `
            $ReportDirectory `
            "PrivilegedAccessFindings-$timestamp.csv"

        $Assignments |
            Export-Csv `
                -Path $assignmentReport `
                -NoTypeInformation

        $Findings |
            Export-Csv `
                -Path $findingsReport `
                -NoTypeInformation

        Write-Log `
            -Message "Assignment report exported to $assignmentReport" `
            -Level "SUCCESS"

        Write-Log `
            -Message "Findings report exported to $findingsReport" `
            -Level "SUCCESS"

        return [PSCustomObject]@{
            AssignmentReport = $assignmentReport
            FindingsReport   = $findingsReport
        }
       Write-Host ""
Write-Host "===================================="
Write-Host " Privileged Access Review Complete"
Write-Host "====================================" 
    }
    catch {
        Write-Log `
            -Message "Failed to export reports: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}
function Show-PrivilegedAccessSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Roles,

        [Parameter(Mandatory)]
        $Assignments,

        [Parameter(Mandatory)]
        $Findings
    )

    $multipleRoleCount = ($Findings |
        Where-Object Finding -eq "Multiple Privileged Roles").Count

    $disabledCount = ($Findings |
        Where-Object Finding -eq "Disabled Privileged Account").Count

    $guestCount = ($Findings |
        Where-Object Finding -eq "Guest Privileged Account").Count

    if ($disabledCount -gt 0 -or $guestCount -gt 0) {
        $overallRisk = "High"
    }
    elseif ($multipleRoleCount -gt 0) {
        $overallRisk = "Medium"
    }
    else {
        $overallRisk = "Low"
    }

    Write-Host ""
    Write-Host "===================================="
    Write-Host " Privileged Access Review Summary"
    Write-Host ("Generated: {0}" -f (Get-Date))
Write-Host ""
    Write-Host "===================================="
    Write-Host ("Total Active Roles:              {0}" -f $Roles.Count)
    Write-Host ("Total Privileged Assignments:    {0}" -f $Assignments.Count)
    Write-Host ""
    Write-Host ("Multiple Role Findings:          {0}" -f $multipleRoleCount)
    Write-Host ("Disabled Privileged Accounts:    {0}" -f $disabledCount)
    Write-Host ("Guest Privileged Accounts:       {0}" -f $guestCount)
    Write-Host ""
    Write-Host ("Overall Risk Level:              {0}" -f $overallRisk)
}