function Get-AuthenticationFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$AssessmentScope
    )

    Write-LabLog -Message 'Starting authentication audit.'

    $strongMethodTypes = @(
        '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'
        '#microsoft.graph.fido2AuthenticationMethod'
        '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod'
        '#microsoft.graph.softwareOathAuthenticationMethod'
        '#microsoft.graph.platformCredentialAuthenticationMethod'
        '#microsoft.graph.x509CertificateAuthenticationMethod'
        '#microsoft.graph.externalAuthenticationMethod'
    )

    $authenticationScope = @(
        $AssessmentScope |
            Where-Object {
                $_.IdentityType -eq 'User' -and
                $_.AuthenticationAudit -eq 'Yes'
            }
    )

    $findings = foreach ($identity in $authenticationScope) {
        $upn = $identity.UserPrincipalName

        try {
            $encodedUpn = [System.Uri]::EscapeDataString($upn)
            $uri = "https://graph.microsoft.com/v1.0/users/$encodedUpn/authentication/methods"

            $response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $uri `
                -ErrorAction Stop

            $methodTypes = @(
                $response.value |
                    ForEach-Object { $_['@odata.type'] } |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            $strongMethods = @(
                $methodTypes |
                    Where-Object { $_ -in $strongMethodTypes }
            )

            Write-LabLog -Message (
                '{0} has {1} recognized strong authentication method(s).' -f
                $upn,
                $strongMethods.Count
            )

            if ($strongMethods.Count -eq 0) {
                $displayMethods = @(
                    $methodTypes |
                        ForEach-Object {
                            $_ -replace '#microsoft.graph.', ''
                        }
                )

                [PSCustomObject]@{
                    UserPrincipalName = $upn
                    FindingType       = 'No Strong Authentication Method'
                    MethodsDetected   = if ($displayMethods) {
                        $displayMethods -join '; '
                    }
                    else {
                        'None'
                    }
                    Severity          = 'Medium'
                    Details           = 'No recognized strong authentication method is registered.'
                }
            }
        }
        catch {
            Write-LabLog `
                -Message "Could not audit authentication for ${upn}: $($_.Exception.Message)" `
                -Level WARNING
        }
    }

    Write-LabLog -Message "Authentication audit found $(@($findings).Count) finding(s)."
    return @($findings)
}

function Show-AuthenticationFindings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Findings
    )

    if ($Findings.Count -eq 0) {
        Write-Host 'No authentication findings detected.' -ForegroundColor Green
        return
    }

    $format = '{0,-52} {1,-36} {2,-42} {3,-10} {4}'

    Write-Host (
        $format -f
        'UserPrincipalName',
        'FindingType',
        'MethodsDetected',
        'Severity',
        'Details'
    ) -ForegroundColor Cyan

    Write-Host ('-' * 175) -ForegroundColor DarkGray

    foreach ($finding in $Findings) {
        $color = switch ($finding.Severity) {
            'High'   { 'Red' }
            'Medium' { 'Yellow' }
            'Low'    { 'Green' }
            default  { 'White' }
        }

        Write-Host (
            $format -f
            $finding.UserPrincipalName,
            $finding.FindingType,
            $finding.MethodsDetected,
            $finding.Severity,
            $finding.Details
        ) -ForegroundColor $color
    }
}