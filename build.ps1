#requires -Module @{ ModuleName = "ModuleBuilder"; ModuleVersion = "2.0" }
using namespace System.Windows.Automation
using namespace System.Windows.Automation.Text
[CmdletBinding()]
param()
$ErrorActionPreference = "STOP"
# WASP 3.0 is based on UIAutomation 3 using UIAComWrapper https://github.com/TestStack/UIAComWrapper
Add-Type -Path $PSScriptRoot\Source\lib\*.dll
# -- a lot of commands have weird names because they're being generated based on pattern names
# -- eg: Invoke-Toggle.Toggle and Invoke-Invoke.Invoke

New-Item -Type Directory $PSScriptRoot\Source\Public\Generated -Force -ErrorAction Stop
New-Item -Type Directory $PSScriptRoot\Source\Private\Generated -Force -ErrorAction Stop
Push-Location $PSScriptRoot\Source\Public\Generated -ErrorAction Stop
Remove-Item -Verbose *.ps1

$patterns = Get-Type -Assembly UIAComWrapper -Base System.Windows.Automation.BasePattern

## TODO: Write Get-SupportedPatterns or rather ...
## Get-SupportedFunctions (to return the names of the functions for the supported patterns)
## TODO: Support all the "Properties" too
## TODO: Figure out why Notepad doesn't support SetValue
## TODO: Figure out where the menus support went
foreach ($pattern in $patterns) {
    $PatternName = $Pattern.Name -Replace "Pattern", "."
    Write-Information "Generating $PatternName"

    $PatternFullName = $pattern.FullName
    $newline = "`n        "
    $FunctionName = "ConvertTo-$($Pattern.Name)"
    Write-Information "    $FunctionName"
    New-Item -Type File -Name "$FunctionName.ps1" -Force -Value @"
function $FunctionName {
    [CmdletBinding()]
    param(
        # The AutomationElement to convert
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('Element','AutomationElement')]
        [AutomationElement]`$InputObject
    )
    process {
        trap {
            if(`$_.Exception.Message -like '*Unsupported Pattern.*') {
                Write-Error "Cannot get ``"$($Pattern.Name)``" from that AutomationElement, `$(`$_)` You should try one of: `$(`$InputObject.GetSupportedPatterns()|%{``"'``" + (`$_.ProgrammaticName.Replace(``"PatternIdentifiers.Pattern``",``"``")) + ``"Pattern'``"})"; continue;
            }
        }
        Write-Output `$InputObject.GetCurrentPattern([$PatternFullName]::Pattern).Current
    }
}
"@


#     $pattern.GetFields().Where{ $_.FieldType -eq [AutomationEvent] }.ForEach{
#         $FunctionName = "Add-$($_.Name -replace "Event$")Handler"
#         New-Item -Type File -Name "$FunctionName.ps1" -Value @"
# function $FunctionName {
#     [CmdletBinding()]
#     param(
#         # The AutomationElement to Register the Event handler for
#         [Parameter(Mandatory, ValueFromPipeline)]
#         [Alias('Element','AutomationElement')]
#         [AutomationElement]`$InputObject,
#
#         [AutomationEventHandler]`$Handler,
#
#         [TreeScope]`$Scope = "Element"
#     )
#
#     [Automation]::AddAutomationEventHandler(([$($pattern.FullName)]::$($_.Name)), `$InputObject, `$Scope, `$Handler)
# }
# "@

#         $FunctionName = "Remove-$($_.Name -replace "Event$")Handler"
#         New-Item -Type File -Name "$FunctionName.ps1" -Value @"
# function $FunctionName {
#     [CmdletBinding()]
#     param(
#         # The AutomationElement to Register the Event handler for
#         [Parameter(Mandatory, ValueFromPipeline)]
#         [Alias('Element','AutomationElement')]
#         [AutomationElement]`$InputObject,

#         [AutomationEventHandler]`$Handler
#     )

#     [Automation]::RemoveAutomationEventHandler(([$($pattern.FullName)]::$($_.Name)), `$InputObject, `$Handler)
# }
# "@

#     }


    Write-Information "    Generating Property Functions"
    $pattern.GetProperties().Where{ $_.DeclaringType -eq $_.ReflectedType -and $_.Name -notmatch "Cached|Current" }.ForEach{
        $FunctionName = "Get-$PatternName$($_.Name)".Trim('.')
        Write-Information "        $FunctionName"

        New-Item -Type File "$FunctionName.ps1" -Force -Value @"
function $FunctionName {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AutomationElement]`$AutomationElement
    )
    process {
        trap { Write-Warning "$PatternFullName `$_"; continue }
        `$pattern = `$AutomationElement.GetCurrentPattern([$PatternFullName]::Pattern)
        if(`$pattern) {
            `$pattern.'$($_.Name)'
        }
    }
}
"@
    }

    Write-Information "    Generating Field Functions"
    ## So far this seems to be restricted to Text (DocumentRange) elements
    $pattern.GetFields().Where{ $_.FieldType.Name -like "*TextAttribute" }.ForEach{
        $FunctionName = "Get-Text$($_.Name -replace 'Attribute')"
        Write-Information "        $FunctionName"
        New-Item -Type File -Force "$FunctionName.ps1" -Value @"
function $FunctionName {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AutomationElement]`$AutomationElement
    )
    process {
        trap { Write-Warning "$PatternFullName `$_"; continue }
        `$AutomationElement.GetAttributeValue([$PatternFullName]::$($_.Name))
    }
}
"@
    }

    Write-Information "    Generating Method Functions"

    $pattern.GetMethods().Where{ $_.DeclaringType -eq $_.ReflectedType -and !$_.IsSpecialName }.ForEach{
        $Position = 1
        $FunctionName = "Invoke-$PatternName$($_.Name)"
        Write-Information "        $FunctionName"

        $Parameters = @("$newline[Parameter(ValueFromPipeline)]" +
            "$newline[Alias('Parent', 'Element', 'Root', 'AutomationElement')]" +
            "$newline[AutomationElement]`$InputObject"
        ) +
        @(
            "[Parameter()]$newline[Switch]`$Passthru"
        ) +
        @($_.GetParameters().ForEach{ "[Parameter(Position=$($Position; $Position++))]$newline[$($_.ParameterType.FullName)]`$$($_.Name)" })
        $Parameters = $Parameters -Join ",$newline"
        $ParameterValues = '$' + ($_.GetParameters().Name -Join ', $')
        New-Item -Type File -Force "$FunctionName.ps1" -Value @"
function $FunctionName {
    [CmdletBinding()]
    param(
        $Parameters
    )
    process {
        ## trap { Write-Warning "`$(`$_)"; break }
        `$pattern = `$InputObject.GetCurrentPattern([$PatternFullName]::Pattern)
        if(`$pattern) {
            `$Pattern.$($_.Name)($(if($ParameterValues.Length -gt 1){ $ParameterValues }))
        }
        if(`$passthru) {
            `$InputObject
        }
    }
}
"@

        trap {
            Write-Warning $_
            Write-Host $definition -fore cyan
        }
    }
}

$Event = $patterns.ForEach{
    $Pattern = $_.FullName -replace "System\.Windows\.Automation\."
    $_.GetFields().Where{ $_.FieldType -eq [AutomationEvent] }.ForEach{
        # $Event = $_.Name -replace "Event$"
        # $EventId = "[$Name]::$($_.Name)"
        "[$Pattern]::$($_.Name)"
    }
}

Write-Information "    Generating Variable File"
New-Item -Type File -Force "$PSScriptRoot\Source\Private\Generated\01 - Variables.ps1" -Value @"
`$UIAEvents = @(
    $($Event -join "`n    ")
)
"@

Write-Information "    Generating Add-UIHandler File"
New-Item -Type File "Add-UIHandler.ps1" -Value @"
function Add-UIHandler {
    [CmdletBinding()]
    param(
        # The AutomationElement to Register the Event handler for
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [Alias('Element', 'AutomationElement')]
        [AutomationElement]`$InputObject,

        [ValidateSet('$($Event -replace "^.*::(.*)Event", '$1' -join "','")')]
        [string]`$Event,

        [Parameter(Mandatory, Position = 1)]
        [AutomationEventHandler]`$Handler,

        [TreeScope]`$Scope = "Element"
    )

    `$EventId = `$UIAEvents.Where{ `$_.ProgrammaticName -match `$Event }[0]

    [Automation]::AddAutomationEventHandler(`$EventId, `$InputObject, `$Scope, `$Handler)
}
"@


Write-Information "    Generating Remove-UIHandler File"
New-Item -Type File "Remove-UIHandler.ps1" -Value @"
function Remove-UIHandler {
    [CmdletBinding()]
    param(
        # The AutomationElement to Register the Event handler for
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [Alias('Element', 'AutomationElement')]
        [AutomationElement]`$InputObject,

        [ValidateSet('$($Event -replace "^.*::(.*)Event", '$1' -join "','")')]
        [string]`$Event,

        [Parameter(Mandatory, Position = 1)]
        [AutomationEventHandler]`$Handler,

        [TreeScope]`$Scope = "Element"
    )

    `$EventId = `$UIAEvents.Where{ `$_.ProgrammaticName -match `$Event }

    [Automation]::RemoveAutomationEventHandler(`$EventId, `$InputObject, `$Handler)
}
"@


# $FalseCondition = [Condition]::FalseCondition
# $TrueCondition = [Condition]::TrueCondition
# $AutomationProperties = [System.Windows.Automation.AutomationElement+AutomationElementInformation].GetProperties()

# Set-Alias Invoke-UIElement Invoke-Invoke.Invoke
Write-Information "Build Module"
Set-Location $PSScriptRoot
Build-Module
Pop-Location

#   [Cmdlet(VerbsCommon.Add, "UIAHandler")]
#   public class AddUIAHandlerCommand : PSCmdlet
#   {
#      private AutomationElement _parent = AutomationElement.RootElement;
#      private AutomationEvent _event = WindowPattern.WindowOpenedEvent;
#      private TreeScope _scope = TreeScope.Children;
#
#      [Parameter(ValueFromPipeline = true)]
#      [Alias("Parent", "Element", "Root")]
#      public AutomationElement InputObject { set { _parent = value; } get { return _parent; } }
#
#      [Parameter()]
#      public AutomationEvent Event { set { _event = value; } get { return _event; } }
#
#      [Parameter()]
#      public AutomationEventHandler ScriptBlock { set; get; }
#
#      [Parameter()]
#      public SwitchParameter Passthru { set; get; }
#
#      [Parameter()]
#      public TreeScope Scope { set { _scope = value; } get { return _scope; } }
#
#      protected override void ProcessRecord()
#      {
#         Automation.AddAutomationEventHandler(Event, InputObject, Scope, ScriptBlock);
#
#         if (Passthru.ToBool())
#         {
#            WriteObject(InputObject);
#         }
#
#         base.ProcessRecord();
#      }
#   }

Write-host "Deploy our generated files to the version folder";
Get-ChildItem -Path "${pwd}/Source" | 
    forEach { 
        Copy-Item -Path $_ -Recurse -Destination "${pwd}/3.0.0" -Verbose -Force 
    }
Write-host "Finished."