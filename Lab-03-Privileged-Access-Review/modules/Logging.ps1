function Initialize-Logging {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $script:LogFile = Join-Path `
        -Path $LogDirectory `
        -ChildPath "PrivilegedAccessReview-$timestamp.log"

    New-Item -Path $script:LogFile -ItemType File -Force | Out-Null

    Write-Host "Logging initialized: $script:LogFile"
}

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logEntry
    }
}

function Get-LogFile {
    [CmdletBinding()]
    param()

    return $script:LogFile
}