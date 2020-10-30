using namespace System.Windows.Forms
function Set-UIText {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Text,

        [Parameter(ValueFromPipeline = $true)]
        [Alias("Parent", "Element", "Root")]
        [AutomationElement]$InputObject,

        [Parameter()]
        [Switch]$Passthru
    )
    process {
        if (!$InputObject.Current.IsEnabled) {
            Write-Warning "The Control is not enabled!"
        }
        if (!$InputObject.Current.IsKeyboardFocusable) {
            Write-Warning "The Control is not focusable!"
        }

        $valuePattern = $null
        if ($InputObject.TryGetCurrentPattern([ValuePattern]::Pattern, [ref]$valuePattern)) {
            Write-Verbose "Set via ValuePattern!"
            $valuePattern.SetValue( $Text )
        } elseif ($InputObject.Current.IsKeyboardFocusable) {
            Set-UIFocus $InputObject
            [SendKeys]::SendWait("^{HOME}");
            [SendKeys]::SendWait("^+{END}");
            [SendKeys]::SendWait("{DEL}");
            [SendKeys]::SendWait( $Text )
        }
        if ($passthru) {
            $InputObject
        }
    }
}
