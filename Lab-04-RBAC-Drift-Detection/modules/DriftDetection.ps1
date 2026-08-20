function Get-CurrentRBACState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Baseline
    )

    Write-Log -Message "Retrieving current RBAC group memberships..."

    $ManagedGroups = @(
        $Baseline.ExpectedGroups |
            ForEach-Object { $_ -split ";" } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )

    $CurrentState = foreach ($Record in $Baseline) {
        try {
            Write-Log `
                -Message "Checking memberships for $($Record.UserPrincipalName)."

            $User = Get-MgUser `
                -UserId $Record.UserPrincipalName `
                -Property Id,DisplayName,UserPrincipalName `
                -ErrorAction Stop

            $CurrentGroups = @(
                Get-MgUserMemberOfAsGroup `
                    -UserId $User.Id `
                    -All `
                    -Property Id,DisplayName `
                    -ErrorAction Stop |
                    Where-Object {
                        $_.DisplayName -in $ManagedGroups
                    } |
                    Select-Object -ExpandProperty DisplayName
            )

            [PSCustomObject]@{
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                CurrentGroups     = $CurrentGroups -join ";"
                LookupStatus      = "Success"
            }
        }
        catch {
            Write-Log `
                -Message "Could not retrieve $($Record.UserPrincipalName): $($_.Exception.Message)" `
                -Level "ERROR"

            [PSCustomObject]@{
                DisplayName       = $Record.DisplayName
                UserPrincipalName = $Record.UserPrincipalName
                CurrentGroups     = ""
                LookupStatus      = "Failed"
            }
        }
    }

    Write-Log `
        -Message "Current RBAC state retrieval completed." `
        -Level "SUCCESS"

    return $CurrentState
}
function Compare-RBACState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Baseline,

        [Parameter(Mandatory)]
        [array]$CurrentState
    )

    Write-Log -Message "Comparing expected and current RBAC access..."

    $ComparisonResults = foreach ($BaselineRecord in $Baseline) {
        $CurrentRecord = $CurrentState |
            Where-Object {
                $_.UserPrincipalName -eq $BaselineRecord.UserPrincipalName
            } |
            Select-Object -First 1

        if (-not $CurrentRecord -or $CurrentRecord.LookupStatus -ne "Success") {
            [PSCustomObject]@{
                DisplayName          = $BaselineRecord.DisplayName
                UserPrincipalName    = $BaselineRecord.UserPrincipalName
                ExpectedGroups       = $BaselineRecord.ExpectedGroups
                CurrentGroups        = ""
                MissingGroups        = ""
                UnexpectedGroups     = ""
                ComplianceStatus     = "Unable to Evaluate"
            }

            continue
        }

        $ExpectedGroups = @(
            $BaselineRecord.ExpectedGroups -split ";" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }
        )

        $ActualGroups = @(
            $CurrentRecord.CurrentGroups -split ";" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }
        )

        $MissingGroups = @(
            $ExpectedGroups |
                Where-Object { $_ -notin $ActualGroups }
        )

        $UnexpectedGroups = @(
            $ActualGroups |
                Where-Object { $_ -notin $ExpectedGroups }
        )

        if (
            $MissingGroups.Count -eq 0 -and
            $UnexpectedGroups.Count -eq 0
        ) {
            $ComplianceStatus = "Compliant"
        }
        else {
            $ComplianceStatus = "Drift Detected"
        }

        [PSCustomObject]@{
            DisplayName          = $BaselineRecord.DisplayName
            UserPrincipalName    = $BaselineRecord.UserPrincipalName
            ExpectedGroups       = $ExpectedGroups -join ";"
            CurrentGroups        = $ActualGroups -join ";"
            MissingGroups        = $MissingGroups -join ";"
            UnexpectedGroups     = $UnexpectedGroups -join ";"
            ComplianceStatus     = $ComplianceStatus
        }
    }

    Write-Log `
        -Message "RBAC drift comparison completed." `
        -Level "SUCCESS"

    return $ComparisonResults
}