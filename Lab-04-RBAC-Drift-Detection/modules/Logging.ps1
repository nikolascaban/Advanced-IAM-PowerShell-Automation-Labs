function Initialize-Logging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

    $script:LogFile = Join-Path `
        -Path $LogDirectory `
        -ChildPath "RBACDriftDetection-$Timestamp.log"

    New-Item -Path $script:LogFile -ItemType File -Force | Out-Null

    Write-Host "Logging initialized: $script:LogFile"
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"

    switch ($Level) {
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        default   { Write-Host $LogEntry }
    }

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $LogEntry
    }
}