function Add-UIHandler {
    [CmdletBinding()]
    param(
        # The AutomationElement to Register the Event handler for
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [Alias('Element', 'AutomationElement')]
        [AutomationElement]$InputObject,

        [ValidateSet('DragStart','DragCancel','DragComplete','DropTargetEnter','DropTargetLeave','Dropped','Invoked','InputReachedTarget','InputReachedOtherElement','InputDiscarded','TextChanged','TextSelectionChanged','Invalidated','ElementAddedToSelection','ElementRemovedFromSelection','ElementSelected','WindowClosed','WindowOpened')]
        [string]$Event,

        [Parameter(Mandatory, Position = 1)]
        [AutomationEventHandler]$Handler,

        [TreeScope]$Scope = "Element"
    )

    $EventId = $UIAEvents.Where{ $_.ProgrammaticName -match $Event }

    [Automation]::AddAutomationEventHandler($EventId, $InputObject, $Scope, $Handler)
}