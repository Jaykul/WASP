function Set-UIFocus {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [Alias("Parent", "Element", "Root")]
        [AutomationElement]$InputObject,

        [Parameter()]
        [Switch]$Passthru
    )
    process {
        try {
            [UIAutomationHelper]::SetForeground( $InputObject )
            $InputObject.SetFocus()
        } catch {
            Write-Verbose "SetFocus fail, trying SetForeground"
        }
        if ($passthru) {
            $InputObject
        }
    }
}
