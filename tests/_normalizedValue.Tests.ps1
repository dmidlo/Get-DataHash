Import-Module Pester
Import-Module './Get-DataHash.psd1'

Describe "DataHash::_normalizeValue" -Tags "Normalization" {
    BeforeEach {
        $DataHash = [DataHash]::New()
    }

    It "Replaces null values with '[NULL]'" {
        $result = $DataHash._normalizeValue($null)
        $result | Should -Be "[NULL]"
    }

    It "Returns scalar values unchanged" {
        $DataHash._normalizeValue(42) | Should -Be 42
        $DataHash._normalizeValue("Hello") | Should -Be "Hello"
        $DataHash._normalizeValue($true) | Should -Be $true
    }

    It "Handles deeply nested structures with mixed types" {
        $input = @(
            @{ Name = "Alice"; Age = 30 },
            @(1, 2, 3, @{ Nested = @(4, 5, $null) }),
            "String",
            $true
        )
        $expected = @(
            [Ordered]@{ Age = 30; Name = "Alice" },
            @(1, 2, 3, [Ordered]@{ Nested = @(4, 5, "[NULL]") }),
            "String",
            $true
        )
        $result = $DataHash._normalizeValue($input)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Handles circular references gracefully within lists" {
        $circularList = [System.Collections.Generic.List[object]]::new()
        $circularList.Add($circularList) 

        $result = $DataHash._normalizeValue($circularList)
        $result | Should -Be @("[CIRCULAR_REF]")
    }

    It "Handles lists of PSCustomObjects correctly" {
        $obj1 = [PSCustomObject]@{ Name = "Alice"; Age = 30 }
        $obj2 = [PSCustomObject]@{ Name = "Bob"; Age = 25 }

        $InputObject = @($obj1, $obj2)
        $expected = @(
            [Ordered]@{ Age = 30; Name = "Alice" },
            [Ordered]@{ Age = 25; Name = "Bob" }
        )
        $result = $DataHash._normalizeValue($InputObject)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Ignores specified fields in lists of PSCustomObjects" {
        $DataHash.IgnoreFields.Add("Secret")

        $input = @(
            [PSCustomObject]@{ Name = "Alice"; Secret = "Hidden" },
            [PSCustomObject]@{ Name = "Bob"; Age = 25; Secret = "Hidden" }
        )
        $expected = @(
            [Ordered]@{ Name = "Alice" },
            [Ordered]@{ Age = 25; Name = "Bob" }
        )
        $result = $DataHash._normalizeValue($input)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Handles nested dictionaries inside lists correctly" {
        $input = @(
            @{ Outer = @{ Inner = @{ Key = "Value" } } },
            @{ Another = 42 }
        )
        $expected = @(
            [Ordered]@{ Outer = [Ordered]@{ Inner = [Ordered]@{ Key = "Value" } } },
            [Ordered]@{ Another = 42 }
        )
        $result = $DataHash._normalizeValue($input)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Sorts an unordered list but keeps nested ordered lists intact" {
        $unorderedList = [System.Collections.Generic.HashSet[object]]::new(@(3, 1, 2, [System.Collections.Generic.List[object]]@(5, 4)))
        $expected = @(1, 2, 3, @(5, 4))  # Outer list sorted, inner remains ordered

        $result = $DataHash._normalizeValue($unorderedList)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Handles dictionaries with lists of dictionaries" {
        $input = @{
            Users = @(
                @{ Name = "Alice"; Age = 30 }
                @{ Name = "Bob"; Age = 25 }
            )
        }
        $expected = [Ordered]@{
            Users = @(
                [Ordered]@{ Age = 30; Name = "Alice" }
                [Ordered]@{ Age = 25; Name = "Bob" }
            )
        }
        $result = $DataHash._normalizeValue($input)
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }

    It "Handles unsupported types inside lists gracefully" {
        $customObject = New-Object System.Diagnostics.Stopwatch
        $result = $DataHash._normalizeValue(@(42, $customObject, "Test"))

        $expected = @(42, "[UNSUPPORTED_TYPE:System.Diagnostics.Stopwatch]", "Test")
    
        ($result | ConvertTo-Json -Depth 10) | Should -BeExactly ($expected | ConvertTo-Json -Depth 10)
    }
}
