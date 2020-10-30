function Get-ClickablePoint {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [Alias("Parent", "Element", "Root")]
        [AutomationElement]$InputObject
    )
    process {
        $InputObject.GetClickablePoint()
    }
}
