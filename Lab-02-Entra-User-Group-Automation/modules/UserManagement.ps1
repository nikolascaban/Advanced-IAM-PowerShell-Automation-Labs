# ------------------------------------------------------------
# User-management functions
# ------------------------------------------------------------

function Get-EntraUserByUpn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserPrincipalName
    )

    try {
        return Get-MgUser `
            -UserId $UserPrincipalName `
            -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department,JobTitle `
            -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match "Request_ResourceNotFound|404|does not exist") {
            return $null
        }

        throw
    }
}

function New-EntraUserFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    if ($ExistingUser) {
        $Message = "User already exists: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    $PasswordProfile = @{
        Password                      = "IAMLab2026!"
        ForceChangePasswordNextSignIn = $true
    }

    try {
        $NewUser = New-MgUser `
            -AccountEnabled:$true `
            -DisplayName $UserAction.DisplayName `
            -UserPrincipalName $UserAction.UserPrincipalName `
            -MailNickname $UserAction.MailNickname `
            -Department $UserAction.Department `
            -JobTitle $UserAction.JobTitle `
            -UsageLocation $UserAction.UsageLocation `
            -PasswordProfile $PasswordProfile

        $Message = "Created user: $($NewUser.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to create $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Create" `
            -Status "Failed" `
            -Details $Message
    }
}

function Update-EntraUserFromCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    if (-not $ExistingUser) {
        $Message = "Cannot update user because the account was not found: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        Update-MgUser `
            -UserId $ExistingUser.Id `
            -DisplayName $UserAction.DisplayName `
            -Department $UserAction.Department `
            -JobTitle $UserAction.JobTitle `
            -UsageLocation $UserAction.UsageLocation

        $Message = "Updated user attributes for $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to update $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action "Update" `
            -Status "Failed" `
            -Details $Message
    }
}

function Set-EntraUserEnabledState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$UserAction,

        [Parameter(Mandatory)]
        [bool]$AccountEnabled
    )

    $ExistingUser = Get-EntraUserByUpn `
        -UserPrincipalName $UserAction.UserPrincipalName

    $ActionName = if ($AccountEnabled) {
        "Enable"
    }
    else {
        "Disable"
    }

    if (-not $ExistingUser) {
        $Message = "Cannot $($ActionName.ToLower()) user because the account was not found: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Skipped" `
            -Details $Message

        return
    }

    if ($ExistingUser.AccountEnabled -eq $AccountEnabled) {
        $CurrentStatus = if ($AccountEnabled) {
            "enabled"
        }
        else {
            "disabled"
        }

        $Message = "User is already $CurrentStatus`: $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "WARNING"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Skipped" `
            -Details $Message

        return
    }

    try {
        Update-MgUser `
            -UserId $ExistingUser.Id `
            -AccountEnabled:$AccountEnabled

        $Message = "$ActionName completed for $($UserAction.UserPrincipalName)"

        Write-Log -Message $Message -Level "SUCCESS"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Success" `
            -Details $Message
    }
    catch {
        $Message = "Failed to $($ActionName.ToLower()) $($UserAction.UserPrincipalName): $($_.Exception.Message)"

        Write-Log -Message $Message -Level "ERROR"

        Add-ReportRecord `
            -ObjectType "User" `
            -ObjectName $UserAction.DisplayName `
            -Action $ActionName `
            -Status "Failed" `
            -Details $Message
    }
}

function Invoke-UserActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$UserActions
    )

    Write-Log -Message "Beginning user-action processing."

    foreach ($UserAction in $UserActions) {
        $Action = $UserAction.Action.Trim()

        Write-Log -Message "Processing user action '$Action' for $($UserAction.DisplayName)."

        switch ($Action.ToLower()) {
            "create" {
                New-EntraUserFromCsv -UserAction $UserAction
            }

            "update" {
                Update-EntraUserFromCsv -UserAction $UserAction
            }

            "enable" {
                Set-EntraUserEnabledState `
                    -UserAction $UserAction `
                    -AccountEnabled $true
            }

            "disable" {
                Set-EntraUserEnabledState `
                    -UserAction $UserAction `
                    -AccountEnabled $false
            }

            default {
                $Message = "Unsupported user action '$Action' for $($UserAction.DisplayName)."

                Write-Log -Message $Message -Level "WARNING"

                Add-ReportRecord `
                    -ObjectType "User" `
                    -ObjectName $UserAction.DisplayName `
                    -Action $Action `
                    -Status "Skipped" `
                    -Details $Message
            }
        }
    }

    Write-Log -Message "Finished user-action processing."
}
