Import-Module Pester
Import-Module './Get-DataHash.psd1'

Describe "_NormalizeList" -Tags "Normalization" {
    BeforeAll {
        # Mock IgnoreFields HashSet
        $IgnoreFields = [System.Collections.Generic.HashSet[string]]::new()
    }

    It "Preserves order for ordered lists" {
        $DataHash = [DataHash]::new()
        $orderedList = [System.Collections.Generic.List[object]]@("A", "B", "C")
        $result = $DataHash._normalizeList($orderedList)

        $result | Should -BeExactly @("A", "B", "C")
    }

    It "Sorts unordered collections deterministically" {
        $DataHash = [DataHash]::new()
        $unorderedSet = [System.Collections.Generic.HashSet[object]]::new(@("B", "A", "C"))  
        $result = $DataHash._normalizeList($unorderedSet)

        $result | Should -BeExactly @("A", "B", "C")
    }

    It "Handles mixed data types correctly" {
        $DataHash = [DataHash]::new()
        $mixedList = @(42, "Test", $true, 3.14)
        $result = $DataHash._normalizeList($mixedList)

        $result | Should -BeExactly @(42, "Test", $true, [DataHash]::_NormalizeFloat(3.14))
    }

    It "Handles empty lists correctly" {
        $DataHash = [DataHash]::new()
        $emptyList = @()
        $result = $DataHash._normalizeList($emptyList)

        $result | Should -BeExactly @()
    }

    It "Handles null values inside a list" {
        $DataHash = [DataHash]::new()
        $listWithNulls = @(1, $null, "X")
        $result = $DataHash._normalizeList($listWithNulls)

        $result | Should -BeExactly @(1, "[NULL]", "X")
    }

    It "Handles circular references gracefully" {
        $DataHash = [DataHash]::new()
        $circularList = [System.Collections.Generic.List[object]]::new()
        $circularList.Add($circularList)  # Self-referencing

        $result = $DataHash._normalizeList($circularList)

        $result | Should -BeExactly @("[CIRCULAR_REF]")
    }


    It "Handles nested lists correctly" {
        $DataHash = [DataHash]::new()
        $nestedList = @(1, @(2, 3), 4)
        $result = $DataHash._normalizeList($nestedList)

        $result | Should -BeExactly @(1, @(2, 3), 4)  # Order preserved
    }

    It "Sorts a unordered object nested within an ordered one" {
        $DataHash = [DataHash]::new()

        $unorderedNestedSet = [System.Collections.Generic.HashSet[object]]::new(@(3, 2))  
        $orderedUnordered = @(1, $unorderedNestedSet, 4)
        $orderedUnorderedResult = $DataHash._normalizeList($orderedUnordered)
        $orderedUnorderedResult | Should -BeExactly @(1, @(2, 3), 4)
    }
    
    It "It maintains the order of an ordered object nested in another ordered object" {
        $DataHash = [DataHash]::new()

        $orderedNestedList = [System.Collections.Generic.List[object]]::new(@(3, 2))
        $orderedOrdered = @(1, $orderedNestedList, 4)
        $orderedOrderedResult = $DataHash._normalizeList($orderedOrdered)
        $orderedOrderedResult | Should -BeExactly @(1, @(3, 2), 4)
    }

    It "Sorts an unordered list nested within another unordered list that also sorted" {
        $DataHash = [DataHash]::new()

        $unorderedNestedSet = [System.Collections.Generic.HashSet[object]]::new(@(3, 2))  
        $unorderedUnordered = [System.Collections.Generic.HashSet[object]]::new(@(4, $unorderedNestedSet, 1))
        $unorderedUnorderedResult = $DataHash._normalizeList($unorderedUnordered)
        $unorderedUnorderedResult | Should -BeExactly @(1, 4, @(2, 3))
    }

    It "Sorts an unordered parent list but not an ordered nested list" {
        $DataHash = [DataHash]::new()

        $orderedNestedList = [System.Collections.Generic.List[object]]::new(@(3, 2))
        $unorderedOrdered = [System.Collections.Generic.HashSet[object]]::new(@(4, $orderedNestedList, 1))
        $unorderedOrderedResult = $DataHash._normalizeList($unorderedOrdered)
        $unorderedOrderedResult | Should -BeExactly @(1, 4, @(3, 2))
    }

    It "Normalizes floating point numbers properly" {
        $DataHash = [DataHash]::new()
        $floatList = @(3.14, 2.71)
        $result = $DataHash._normalizeList($floatList)

        $expectedFloats = @([DataHash]::_NormalizeFloat(3.14), [DataHash]::_NormalizeFloat(2.71))
        $result | Should -BeExactly $expectedFloats
    }

    It "Handles boolean values correctly" {
        $DataHash = [DataHash]::new()
        $boolList = @( $true, $false, $true )
        $result = $DataHash._normalizeList($boolList)

        $result | Should -BeExactly @( $true, $false, $true )
    }
}
