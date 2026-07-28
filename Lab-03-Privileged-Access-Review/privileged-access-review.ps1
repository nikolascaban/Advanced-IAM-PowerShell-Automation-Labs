$projectRoot = $PSScriptRoot
$modulePath = Join-Path $projectRoot "modules"
$logDirectory = Join-Path $projectRoot "logs"
$reportDirectory = Join-Path $projectRoot "reports"

. (Join-Path $modulePath "Logging.ps1")
. (Join-Path $modulePath "GraphConnection.ps1")
. (Join-Path $modulePath "RoleAudit.ps1")
. (Join-Path $modulePath "Reporting.ps1")

Initialize-Logging -LogDirectory $logDirectory

try {
    Write-Log -Message "Privileged access review started."

    $graphContext = Connect-PrivilegedAccessGraph

    $roles = Get-DirectoryRoles
$assignments = Get-RoleAssignments -Roles $roles
$multipleRoleFindings = Find-MultiplePrivilegedRoles -Assignments $assignments
$disabledAccountFindings = Find-DisabledPrivilegedAccounts -Assignments $assignments
$guestAccountFindings = Find-GuestPrivilegedAccounts -Assignments $assignments

$allFindings = @(
    $multipleRoleFindings
    $disabledAccountFindings
    $guestAccountFindings
)
$reportFiles = Export-PrivilegedAccessReports `
    -Assignments $assignments `
    -Findings $allFindings `
    -ReportDirectory $reportDirectory
Write-Host ""
Write-Host "Privileged Access Findings"
Write-Host "--------------------------"

if ($allFindings.Count -gt 0) {
    $allFindings |
        Sort-Object RiskLevel, DisplayName |
        Format-Table DisplayName, RiskLevel, Finding, RoleCount, Roles -AutoSize
}
else {
    Write-Host "No privileged access risks were detected."
}
Write-Host ""
Write-Host "Privileged Role Assignments"
Write-Host "---------------------------"

$assignments |
    Format-Table DisplayName, Role, UserType -AutoSize
    Write-Host ""
    Write-Host "Active Directory Roles"
    Write-Host "----------------------"

    $roles |
        Select-Object DisplayName |
        Format-Table -AutoSize

    Write-Log `
        -Message "Directory role retrieval test completed." `
        -Level "SUCCESS"

Write-Host ""
Write-Host "Reports Created"
Write-Host "---------------"
Write-Host $reportFiles.AssignmentReport
Write-Host $reportFiles.FindingsReport
Show-PrivilegedAccessSummary `
    -Roles $roles `
    -Assignments $assignments `
    -Findings $allFindings
    Write-Host ""
Write-Host "===================================="
Write-Host " Privileged Access Review Complete"
Write-Host "===================================="
}
catch {
    Write-Log `
        -Message "The script stopped because an error occurred: $($_.Exception.Message)" `
        -Level "ERROR"
        throw
}
finally {
    if (Get-MgContext) {
        Disconnect-PrivilegedAccessGraph
    }
}