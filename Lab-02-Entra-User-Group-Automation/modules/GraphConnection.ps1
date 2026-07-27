function Connect-ToMicrosoftGraph {
    [CmdletBinding()]
    param()

    $RequiredScopes = @(
        "User.ReadWrite.All"
        "Group.ReadWrite.All"
    )

    Write-Log -Message "Connecting to Microsoft Graph."

    Connect-MgGraph `
        -Scopes $RequiredScopes `
        -UseDeviceCode `
        -NoWelcome

    $Context = Get-MgContext

    if (-not $Context) {
        throw "Microsoft Graph authentication failed."
    }

    Write-Log `
        -Message "Connected to Microsoft Graph as $($Context.Account)." `
        -Level "SUCCESS"
}
