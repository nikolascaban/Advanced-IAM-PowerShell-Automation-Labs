function Initialize-LabLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $script:LogFile = Join-Path `
        -Path $LogDirectory `
        -ChildPath "IdentityAssessment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    New-Item -Path $script:LogFile -ItemType File -Force | Out-Null

    return $script:LogFile
}

function Write-LabLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogFile) {
        throw 'The log has not been initialized. Run Initialize-LabLog first.'
    }

    $entry = '{0} [{1}] {2}' -f `
        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), `
        $Level, `
        $Message

    Add-Content -Path $script:LogFile -Value $entry
    Write-Host $entry
}