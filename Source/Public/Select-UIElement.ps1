function Select-UIElement {
    [CmdletBinding(DefaultParameterSetName = "FromParent")]
    param(
        [Parameter(ParameterSetName = "FromWindowHandle", Position = "0", Mandatory = $true)]
        [Alias("MainWindowHandle", "hWnd", "Handle", "Wh")]
        [IntPtr[]]$WindowHandle = [IntPtr]::Zero,

        [Parameter(ParameterSetName = "FromPoint", Position = "0", Mandatory = $true)]
        [System.Windows.Point[]]$Point,

        [Parameter(ParameterSetName = "FromParent", ValueFromPipeline = $true, Position = 100)]
        [System.Windows.Automation.AutomationElement]$Parent = [UIAutomationHelper]::RootElement,

        [Parameter(ParameterSetName = "FromParent", Position = "0")]
        [Alias("WindowName")]
        [String[]]$Name,

        [Parameter(ParameterSetName = "FromParent", Position = "1")]
        [Alias("Type", "Ct")]
        [System.Windows.Automation.ControlType]
        [StaticField(([System.Windows.Automation.ControlType]))]$ControlType,

        [Parameter(ParameterSetName = "FromParent")]
        [Alias("UId")]
        [String[]]$AutomationId,

        ## Removed "Id" alias to allow get-process | Select-Window pipeline to find just MainWindowHandle
        [Parameter(ParameterSetName = "FromParent", ValueFromPipelineByPropertyName = $true )]
        [Alias("Id")]
        [Int[]]$PID,

        [Parameter(ParameterSetName = "FromParent")]
        [Alias("Pn")]
        [String[]]$ProcessName,

        [Parameter(ParameterSetName = "FromParent")]
        [Alias("Cn")]
        [String[]]$ClassName,

        [switch]$Recurse,

        [switch]$Bare,

        [Parameter(ParameterSetName = "FromParent")]
        #[Alias("Pv")]
        [Hashtable]$PropertyValue

    )
    process {

        Write-Debug "Parameters Found"
        Write-Debug ($PSBoundParameters | Format-Table | Out-String)

        $search = "Children"
        if ($Recurse) {
            $search = "Descendants"
        }

        $condition = [System.Windows.Automation.Condition]::TrueCondition

        Write-Verbose $PSCmdlet.ParameterSetName
        switch -regex ($PSCmdlet.ParameterSetName) {
            "FromWindowHandle" {
                Write-Verbose "Finding from Window Handle $HWnd"
                $Element = $(
                    foreach ($hWnd in $WindowHandle) {
                        [System.Windows.Automation.AutomationElement]::FromHandle( $hWnd )
                    }
                )
                continue
            }
            "FromPoint" {
                Write-Verbose "Finding from Point $Point"
                $Element = $(
                    foreach ($pt in $Point) {
                        [System.Windows.Automation.AutomationElement]::FromPoint( $pt )
                    }
                )
                continue
            }
            "FromParent" {
                Write-Verbose "Finding from Parent!"
                ## [System.Windows.Automation.Condition[]]$conditions = [System.Windows.Automation.Condition]::TrueCondition
                [ScriptBlock[]]$filters = @()
                if ($AutomationId) {
                    [System.Windows.Automation.Condition[]]$current = $(
                        foreach ($aid in $AutomationId) {
                            New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::AutomationIdProperty), $aid
                        }
                    )
                    if ($current.Length -gt 1) {
                        [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                    } elseif ($current.Length -eq 1) {
                        [System.Windows.Automation.Condition[]]$conditions += $current[0]
                    }
                }
                if ($PID) {
                    [System.Windows.Automation.Condition[]]$current = $(
                        foreach ($p in $PID) {
                            New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $p
                        }
                    )
                    if ($current.Length -gt 1) {
                        [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                    } elseif ($current.Length -eq 1) {
                        [System.Windows.Automation.Condition[]]$conditions += $current[0]
                    }
                }
                if ($ProcessName) {
                    if ($ProcessName -match "\?|\*|\[") {
                        [ScriptBlock[]]$filters += { $(foreach ($p in $ProcessName) {
                                    (Get-Process -Id $_.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::ProcessIdProperty)).ProcessName -like $p
                                }) -contains $true }
                    } else {
                        [System.Windows.Automation.Condition[]]$current = $(
                            foreach ($p in Get-Process -Name $ProcessName) {
                                New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ProcessIdProperty), $p.id
                            }
                        )
                        if ($current.Length -gt 1) {
                            [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                        } elseif ($current.Length -eq 1) {
                            [System.Windows.Automation.Condition[]]$conditions += $current[0]
                        }
                    }
                }
                if ($Name) {
                    Write-Verbose "Name: $Name"
                    if ($Name -match "\?|\*|\[") {
                        [ScriptBlock[]]$filters += { $(foreach ($n in $Name) {
                                    $_.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::NameProperty) -like $n
                                }) -contains $true }
                    } else {
                        [System.Windows.Automation.Condition[]]$current = $(
                            foreach ($n in $Name) {
                                New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::NameProperty), $n, "IgnoreCase"
                            }
                        )
                        if ($current.Length -gt 1) {
                            [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                        } elseif ($current.Length -eq 1) {
                            [System.Windows.Automation.Condition[]]$conditions += $current[0]
                        }
                    }
                }
                if ($ClassName) {
                    if ($ClassName -match "\?|\*|\[") {
                        [ScriptBlock[]]$filters += { $(foreach ($c in $ClassName) {
                                    $_.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::ClassNameProperty) -like $c
                                }) -contains $true }
                    } else {
                        [System.Windows.Automation.Condition[]]$current = $(
                            foreach ($c in $ClassName) {
                                New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ClassNameProperty), $c, "IgnoreCase"
                            }
                        )
                        if ($current.Length -gt 1) {
                            [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                        } elseif ($current.Length -eq 1) {
                            [System.Windows.Automation.Condition[]]$conditions += $current[0]
                        }
                    }
                }
                if ($ControlType) {
                    if ($ControlType -match "\?|\*|\[") {
                        [ScriptBlock[]]$filters += { $(foreach ($c in $ControlType) {
                                    $_.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::ControlTypeProperty) -like $c
                                }) -contains $true }
                    } else {
                        [System.Windows.Automation.Condition[]]$current = $(
                            foreach ($c in $ControlType) {
                                New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), $c
                            }
                        )
                        if ($current.Length -gt 1) {
                            [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                        } elseif ($current.Length -eq 1) {
                            [System.Windows.Automation.Condition[]]$conditions += $current[0]
                        }
                    }
                }
                if ($PropertyValue) {
                    $Property = $PropertyValue.Keys[0]
                    $Value = $PropertyValue.Values[0]
                    if ($Value -match "\?|\*|\[") {
                        [ScriptBlock[]]$filters += { $(foreach ($c in $PropertyValue.GetEnumerator()) {
                                    $_.GetCurrentPropertyValue(
                                        [System.Windows.Automation.AutomationElement].GetField(
                                            $c.Key).GetValue(([system.windows.automation.automationelement]))
                                    ) -like $c.Value
                                }) -contains $true }
                    } else {
                        [System.Windows.Automation.Condition[]]$current = $(
                            foreach ($c in $PropertyValue.GetEnumerator()) {
                                New-Object System.Windows.Automation.PropertyCondition (
                                    [System.Windows.Automation.AutomationElement].GetField(
                                        $c.Key).GetValue(([system.windows.automation.automationelement]))), $c.Value
                            }
                        )
                        if ($current.Length -gt 1) {
                            [System.Windows.Automation.Condition[]]$conditions += New-Object System.Windows.Automation.OrCondition $current
                        } elseif ($current.Length -eq 1) {
                            [System.Windows.Automation.Condition[]]$conditions += $current[0]
                        }
                    }
                }

                if ($conditions.Length -gt 1) {
                    [System.Windows.Automation.Condition]$condition = New-Object System.Windows.Automation.AndCondition $conditions
                } elseif ($conditions) {
                    [System.Windows.Automation.Condition]$condition = $conditions[0]
                } else {
                    [System.Windows.Automation.Condition]$condition = [System.Windows.Automation.Condition]::TrueCondition
                }

                If ($VerbosePreference -gt "SilentlyContinue") {

                    function Write-Condition {
                        param([Parameter(ValueFromPipeline = $true)]$condition, $indent = 0)
                        process {
                            Write-Debug ($Condition | fl *  | Out-String)
                            if ($condition -is [System.Windows.Automation.AndCondition] -or $condition -is [System.Windows.Automation.OrCondition]) {
                                Write-Verbose ((" " * $indent) + $Condition.GetType().Name )
                                $condition.GetConditions().GetEnumerator() | Write-Condition -Indent ($Indent + 4)
                            } elseif ($condition -is [System.Windows.Automation.PropertyCondition]) {
                                Write-Verbose ((" " * $indent) + $Condition.Property.ProgrammaticName + " = '" + $Condition.Value + "' (" + $Condition.Flags + ")")
                            } else {
                                Write-Verbose ((" " * $indent) + $Condition.GetType().Name + " where '" + $Condition.Value + "' (" + $Condition.Flags + ")")
                            }
                        }
                    }

                    Write-Verbose "CONDITIONS ============="
                    $global:LastCondition = $condition
                    foreach ($c in $condition) {
                        Write-Condition $c
                    }
                    Write-Verbose "============= CONDITIONS"
                }

                if ($filters.Count -gt 0) {
                    $Element = $Parent.FindAll( $search, $condition ) | Where-Object { $item = $_; foreach ($f in $filters) {
                            $item = $item | where $f
                        }; $item }
                } else {
                    $Element = $Parent.FindAll( $search, $condition )
                }
            }
        }

        Write-Verbose "Element Count: $(@($Element).Count)"
        if ($Element) {
            foreach ($el in $Element) {
                if ($Bare) {
                    Write-Output $el
                } else {
                    $e = New-Object PSObject $el
                    foreach ($prop in $e.GetSupportedProperties() | sort ProgrammaticName) {
                        ## TODO: make sure all these show up: [System.Windows.Automation.AutomationElement] | gm -sta -type Property
                        $propName = [System.Windows.Automation.Automation]::PropertyName($prop)
                        Add-Member -InputObject $e -Type ScriptProperty -Name $propName -Value ([ScriptBlock]::Create( "`$this.GetCurrentPropertyValue( [System.Windows.Automation.AutomationProperty]::LookupById( $($prop.Id) ))" )) -EA 0
                    }
                    foreach ($patt in $e.GetSupportedPatterns() | sort ProgrammaticName) {
                        Add-Member -InputObject $e -Type ScriptProperty -Name ($patt.ProgrammaticName.Replace("PatternIdentifiers.Pattern", "") + "Pattern") -Value ([ScriptBlock]::Create( "`$this.GetCurrentPattern( [System.Windows.Automation.AutomationPattern]::LookupById( '$($patt.Id)' ) )" )) -EA 0
                    }
                    Write-Output $e
                }
            }
        }
    }
}
