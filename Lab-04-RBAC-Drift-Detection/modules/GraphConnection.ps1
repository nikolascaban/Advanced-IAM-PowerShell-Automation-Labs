function Connect-RBACGraph {
    [CmdletBinding()]
    param()
$ExistingContext = Get-MgContext

if ($ExistingContext) {
    Write-Log `
        -Message "Already connected to Microsoft Graph as $($ExistingContext.Account)." `
        -Level "SUCCESS"

    return $ExistingContext
}
    $RequiredScopes = @(
        "User.Read.All"
        "GroupMember.Read.All"
    )

    try {
        Write-Log -Message "Connecting to Microsoft Graph..."

        Connect-MgGraph `
            -Scopes $RequiredScopes `
            -UseDeviceCode `
            -NoWelcome `
            -ErrorAction Stop

        $Context = Get-MgContext

        if (-not $Context) {
            throw "Microsoft Graph connection context was not found."
        }

        Write-Log `
            -Message "Connected to Microsoft Graph as $($Context.Account)." `
            -Level "SUCCESS"

        Write-Log -Message "Tenant ID: $($Context.TenantId)"

        return $Context
    }
    catch {
        Write-Log `
            -Message "Microsoft Graph connection failed: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}

function Disconnect-RBACGraph {
    [CmdletBinding()]
    param()

    try {
        Disconnect-MgGraph -ErrorAction Stop | Out-Null

        Write-Log `
            -Message "Disconnected from Microsoft Graph." `
            -Level "SUCCESS"
    }
    catch {
        Write-Log `
            -Message "Microsoft Graph disconnection failed: $($_.Exception.Message)" `
            -Level "WARNING"
    }
}