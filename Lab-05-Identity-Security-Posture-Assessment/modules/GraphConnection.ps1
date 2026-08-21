function Connect-IdentityAssessmentGraph {
    [CmdletBinding()]
    param()

    $requiredScopes = @(
        'User.Read.All'
        'Group.Read.All'
        'Directory.Read.All'
        'RoleManagement.Read.Directory'
        'UserAuthenticationMethod.Read.All'
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'Microsoft Graph PowerShell is not installed.'
    }

    try {
        Connect-MgGraph `
            -Scopes $requiredScopes `
            -NoWelcome `
            -ErrorAction Stop

        $context = Get-MgContext

        if (-not $context) {
            throw 'Microsoft Graph did not return a connection context.'
        }

        Write-LabLog -Message "Connected to Microsoft Graph as $($context.Account)."
        Write-LabLog -Message "Tenant ID: $($context.TenantId)"

        return $context
    }
    catch {
        Write-LabLog `
            -Message "Microsoft Graph connection failed: $($_.Exception.Message)" `
            -Level ERROR

        throw
    }
}

function Disconnect-IdentityAssessmentGraph {
    [CmdletBinding()]
    param()

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-LabLog -Message 'Disconnected from Microsoft Graph.'
}