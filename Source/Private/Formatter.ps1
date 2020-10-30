function formatter {
    end {
        $input | Format-Table @{l = "Text"; e = { $_.Text.SubString(0, 25) } }, ClassName, FrameworkId -Auto
    }
}