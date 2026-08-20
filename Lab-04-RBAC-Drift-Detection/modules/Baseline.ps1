function Import-RBACBaseline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaselinePath
    )

    try {
        Write-Log -Message "Importing the approved RBAC baseline..."

        if (-not (Test-Path -Path $BaselinePath -PathType Leaf)) {
            throw "Baseline file was not found: $BaselinePath"
        }

        $Baseline = @(
            Import-Csv -Path $BaselinePath
        )

        if ($Baseline.Count -eq 0) {
            throw "The RBAC baseline contains no user records."
        }

        $RequiredColumns = @(
            "DisplayName"
            "UserPrincipalName"
            "Department"
            "ExpectedGroups"
        )

        $ActualColumns = $Baseline[0].PSObject.Properties.Name

        foreach ($Column in $RequiredColumns) {
            if ($Column -notin $ActualColumns) {
                throw "The baseline is missing the required column: $Column"
            }
        }

        Write-Log `
            -Message "Imported $($Baseline.Count) baseline records." `
            -Level "SUCCESS"

        return $Baseline
    }
    catch {
        Write-Log `
            -Message "Failed to import the RBAC baseline: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}