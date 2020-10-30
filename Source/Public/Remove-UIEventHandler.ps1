function Remove-UIEventHandler {
    [CmdletBinding()]
    param()

    [Automation]::RemoveAllEventHandlers()
}