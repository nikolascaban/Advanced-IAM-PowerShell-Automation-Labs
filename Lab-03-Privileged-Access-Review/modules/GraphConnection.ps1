function Connect-PrivilegedAccessGraph {
    [CmdletBinding()]
    param()

    $requiredScopes = @(
        "RoleManagement.Read.Directory"
        "User.Read.All"
    )

    try {
        Write-Log -Message "Connecting to Microsoft Graph..."

        Connect-MgGraph `
            -Scopes $requiredScopes `
            -NoWelcome `
            -ErrorAction Stop

        $context = Get-MgContext

        if (-not $context) {
            throw "Microsoft Graph connection context was not found."
        }

        $grantedScopes = $context.Scopes

        foreach ($scope in $requiredScopes) {
            if ($scope -notin $grantedScopes) {
                throw "Required Microsoft Graph scope was not granted: $scope"
            }
        }

        Write-Log `
            -Message "Connected to Microsoft Graph as $($context.Account)." `
            -Level "SUCCESS"

        Write-Log `
            -Message "Tenant ID: $($context.TenantId)"

        return $context
    }
    catch {
        Write-Log `
            -Message "Microsoft Graph connection failed: $($_.Exception.Message)" `
            -Level "ERROR"

        throw
    }
}

function Disconnect-PrivilegedAccessGraph {
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