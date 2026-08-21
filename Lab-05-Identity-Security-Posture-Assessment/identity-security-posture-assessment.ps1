[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$moduleDirectory = Join-Path $PSScriptRoot 'modules'
$baselineDirectory = Join-Path $PSScriptRoot 'baseline'
$logDirectory = Join-Path $PSScriptRoot 'logs'
$reportDirectory = Join-Path $PSScriptRoot 'reports'

$moduleFiles = @(
    'Logging.ps1'
    'GraphConnection.ps1'
    'PrivilegedAccessAudit.ps1'
    'RBACAudit.ps1'
    'AuthenticationAudit.ps1'
    'AccountHygieneAudit.ps1'
    'ServiceAccountAudit.ps1'
    'Reporting.ps1'
)

foreach ($moduleFile in $moduleFiles) {
    $modulePath = Join-Path $moduleDirectory $moduleFile

    if (-not (Test-Path $modulePath)) {
        throw "Required module was not found: $modulePath"
    }

    . $modulePath
}

$logFile = Initialize-LabLog -LogDirectory $logDirectory
$connectedByScript = $false

try {
    Write-LabLog -Message 'Identity security posture assessment started.'

    $scopePath = Join-Path $baselineDirectory 'AssessmentScope.csv'
    $rbacPath = Join-Path $baselineDirectory 'ExpectedRBAC.csv'
    $serviceAccountPath = Join-Path $baselineDirectory 'ServiceAccounts.csv'

    $requiredFiles = @(
        $scopePath
        $rbacPath
        $serviceAccountPath
    )

    foreach ($requiredFile in $requiredFiles) {
        if (-not (Test-Path $requiredFile)) {
            throw "Required baseline file was not found: $requiredFile"
        }
    }

    $scope = @(Import-Csv $scopePath)
    $rbacBaseline = @(Import-Csv $rbacPath)
    $serviceAccountBaseline = @(Import-Csv $serviceAccountPath)

    if ($scope.Count -eq 0) {
        throw 'AssessmentScope.csv contains no identities.'
    }

    $invalidScopeEntries = @(
        $scope |
            Where-Object {
                [string]::IsNullOrWhiteSpace($_.UserPrincipalName) -or
                [string]::IsNullOrWhiteSpace($_.IdentityType)
            }
    )

    if ($invalidScopeEntries.Count -gt 0) {
        throw 'AssessmentScope.csv contains blank required values.'
    }

    Write-LabLog -Message "Loaded $($scope.Count) scoped identities."

    if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
        Connect-IdentityAssessmentGraph | Out-Null
        $connectedByScript = $true
    }
    else {
        $context = Get-MgContext
        Write-LabLog -Message "Using existing Graph connection for $($context.Account)."
    }

    $sensitiveGroups = @(
        $rbacBaseline.ExpectedGroups |
            ForEach-Object { $_ -split ';' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )

    $privilegedFindings = @(
        Get-PrivilegedAccessFindings -AssessmentScope $scope
    )

    $rbacFindings = @(
        Get-RBACFindings -RBACBaseline $rbacBaseline
    )

    $authenticationFindings = @(
        Get-AuthenticationFindings -AssessmentScope $scope
    )

    $accountHygieneFindings = @(
        Get-AccountHygieneFindings `
            -AssessmentScope $scope `
            -SensitiveGroups $sensitiveGroups
    )

    $serviceAccountFindings = @(
        Get-ServiceAccountFindings `
            -ServiceAccountBaseline $serviceAccountBaseline
    )

    Write-Host ''
    Write-Host 'PRIVILEGED ACCESS FINDINGS' -ForegroundColor Cyan
    Show-PrivilegedAccessFindings -Findings $privilegedFindings
    Write-Host ''
    Write-Host 'RBAC FINDINGS' -ForegroundColor Cyan
    Show-RBACFindings -Findings $rbacFindings

    Write-Host ''
    Write-Host 'AUTHENTICATION FINDINGS' -ForegroundColor Cyan
    Show-AuthenticationFindings -Findings $authenticationFindings

    Write-Host ''
    Write-Host 'ACCOUNT HYGIENE FINDINGS' -ForegroundColor Cyan
    Show-AccountHygieneFindings -Findings $accountHygieneFindings

    Write-Host ''
    Write-Host 'SERVICE ACCOUNT FINDINGS' -ForegroundColor Cyan
    Show-ServiceAccountFindings -Findings $serviceAccountFindings

    $reportResult = Export-AssessmentReports `
        -PrivilegedFindings $privilegedFindings `
        -RBACFindings $rbacFindings `
        -AuthenticationFindings $authenticationFindings `
        -AccountHygieneFindings $accountHygieneFindings `
        -ServiceAccountFindings $serviceAccountFindings `
        -IdentitiesAudited $scope.Count `
        -ReportDirectory $reportDirectory

    Show-PostureSummary -Summary $reportResult.Summary

    Write-LabLog -Message 'Identity security posture assessment completed successfully.'
    Write-Host ""
    Write-Host "Reports: $reportDirectory" -ForegroundColor Green
    Write-Host "Log:     $logFile" -ForegroundColor Green
}
catch {
    Write-LabLog `
        -Message "Assessment failed: $($_.Exception.Message)" `
        -Level ERROR

    Write-Host "Assessment failed: $($_.Exception.Message)" `
        -ForegroundColor Red

    exit 1
}
finally {
    if ($connectedByScript) {
        Disconnect-IdentityAssessmentGraph
    }
}