function Send-UIKeys {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Keys,

        [Parameter(ValueFromPipeline = $true)]
        [Alias("Parent", "Element", "Root")]
        [AutomationElement]$InputObject,

        [Parameter()]
        [Switch]$Passthru,

        [Parameter()]
        [Switch]$Async
    )
    process {
        if (!$InputObject.Current.IsEnabled) {
            Write-Warning "The Control is not enabled!"
        }
        if (!$InputObject.Current.IsKeyboardFocusable) {
            Write-Warning "The Control is not focusable!"
        }
        Set-UIFocus $InputObject

        if ($Async) {
            [SendKeys]::Send( $Keys )
        } else {
            [SendKeys]::SendWait( $Keys )
        }

        if ($passthru) {
            $InputObject
        }
    }
}
