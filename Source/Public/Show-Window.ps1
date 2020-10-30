function Show-Window {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [Alias("Parent", "Element", "Root")]
        [AutomationElement]$InputObject,

        [Parameter()]
        [Switch]$Passthru
    )
    process {
        Set-UIFocus $InputObject
        if ($passthru) {
            $InputObject
        }
    }
}

