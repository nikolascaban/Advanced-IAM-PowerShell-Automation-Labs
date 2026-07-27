function Add-ReportRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectType,

        [Parameter(Mandatory)]
        [string]$ObjectName,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Details
    )

    $Script:ReportResults.Add(
        [PSCustomObject]@{
            Timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ObjectType = $ObjectType
            ObjectName = $ObjectName
            Action     = $Action
            Status     = $Status
            Details    = $Details
        }
    )
}
