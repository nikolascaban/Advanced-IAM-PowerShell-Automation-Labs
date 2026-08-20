#Requires -Version 7.0

$ProjectRoot = $PSScriptRoot
$ModulePath = Join-Path $ProjectRoot "modules"
$LogDirectory = Join-Path $ProjectRoot "logs"
$ReportDirectory = Join-Path $ProjectRoot "reports"
$BaselinePath = Join-Path $ProjectRoot "baseline\ExpectedRBAC.csv"

. (Join-Path $ModulePath "Logging.ps1")
. (Join-Path $ModulePath "GraphConnection.ps1")
. (Join-Path $ModulePath "Baseline.ps1")
. (Join-Path $ModulePath "DriftDetection.ps1")
. (Join-Path $ModulePath "Reporting.ps1")

Initialize-Logging -LogDirectory $LogDirectory

try {
    Write-Log -Message "RBAC drift detection started."

    $GraphContext = Connect-RBACGraph
    $Baseline = Import-RBACBaseline -BaselinePath $BaselinePath
    $CurrentState = Get-CurrentRBACState -Baseline $Baseline
    $ComparisonResults = Compare-RBACState `
    -Baseline $Baseline `
    -CurrentState $CurrentState
    $ComparisonResults = Compare-RBACState `
    -Baseline $Baseline `
    -CurrentState $CurrentState
    Write-Host ""
Write-Host "Current Controlled Group Memberships"
Write-Host "------------------------------------"

$CurrentState |
    Format-Table `
        DisplayName,
        CurrentGroups,
        LookupStatus `
        -AutoSize

    Write-Host ""
    Write-Host "Approved RBAC Baseline"
    Write-Host "----------------------"

    $Baseline |
        Format-Table `
            DisplayName,
            Department,
            ExpectedGroups `
            -AutoSize
          Write-Host ""
Write-Host "RBAC Drift Analysis"
Write-Host "-------------------"

$Header = "{0,-18} {1,-20} {2,-22} {3,-16}" -f `
    "DisplayName",
    "MissingGroups",
    "UnexpectedGroups",
    "ComplianceStatus"

Write-Host $Header -ForegroundColor Cyan
Write-Host ("-" * $Header.Length) -ForegroundColor Cyan

foreach ($Result in $ComparisonResults) {
    $Row = "{0,-18} {1,-20} {2,-22} {3,-16}" -f `
        $Result.DisplayName,
        $Result.MissingGroups,
        $Result.UnexpectedGroups,
        $Result.ComplianceStatus

    if ($Result.ComplianceStatus -eq "Compliant") {
        Write-Host $Row -ForegroundColor Green
    }
    elseif (
        $Result.MissingGroups -and
        $Result.UnexpectedGroups
    ) {
        Write-Host $Row -ForegroundColor Red
    }
    else {
        Write-Host $Row -ForegroundColor Yellow
    }
}        $ReportPath = Export-RBACDriftReport `
    -ComparisonResults $ComparisonResults `
    -ReportDirectory $ReportDirectory

Write-Host ""
Write-Host "Report Created"
Write-Host "--------------"
Write-Host $ReportPath
Show-RBACDriftSummary `
    -ComparisonResults $ComparisonResults
    Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "     RBAC DRIFT DETECTION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

    Write-Log `
        -Message "RBAC drift analysis completed." `
        -Level "SUCCESS"
}
catch {
    Write-Log `
        -Message "The test failed: $($_.Exception.Message)" `
        -Level "ERROR"
}
