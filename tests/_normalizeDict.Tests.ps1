Import-Module Pester
Import-Module './Get-DataHash.psd1'

Describe "DataHash::_NormalizeDict" {
    It "Returns empty hashtable for empty input" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $result = $DataHash._NormalizeDict(@{})
        ($result | ConvertTo-Json) | Should -BeExactly (@{} | ConvertTo-Json)
    }

    It "Preserves ordered dictionaries" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $orderedDict = [ordered]@{ C = 1; A = 2; B = 3 }
        $result = $DataHash._NormalizeDict($orderedDict)

        # Construct expected OrderedDictionary
        $expected = [System.Collections.Specialized.OrderedDictionary]::new()
        $orderedDict.GetEnumerator() | ForEach-Object { $expected[$_.Key] = $_.Value }

        $result.Keys | Should -Be $expected.Keys
        $result.Values | Should -Be $expected.Values
    }

    It "Sorts unordered dictionaries" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $unorderedDict = @{ Z = 1; X = 2; A = 3 }
        $result = $DataHash._NormalizeDict($unorderedDict)

        $expected = [System.Collections.Specialized.OrderedDictionary]::new()
        $unorderedDict.GetEnumerator() | ForEach-Object { $expected[$_.Key] = $_.Value }

        $result.Keys | Should -Be @('A', 'X', 'Z')
        $result.Values | Should -Be @( 3, 2, 1)
    }

    It "Ignores specified fields" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $DataHash.AddIgnoreField('B')
        $testDict = @{ A = 1; B = 2; C = 3 }
        $result = $DataHash._NormalizeDict($testDict)
        $result.Keys | Should -BeExactly @('A', 'C')  # "B" should be excluded
    }

    It "Handles circular references gracefully" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $circularDict = @{ A = 1 }
        $circularDict["Self"] = $circularDict  # Circular reference

        $result = $DataHash._NormalizeDict($circularDict)
        $result["Self"] | Should -BeExactly "[CIRCULAR_REF]"
    }

    It "Processes PSCustomObject properties as dictionary keys" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $obj = [PSCustomObject]@{ Name = "John"; Age = 30 }
        $result = $DataHash._NormalizeDict($obj)

        $result.Keys | Should -BeExactly @('Age', 'Name')  # Sorted property names
        $result["Age"] | Should -BeExactly 30
        $result["Name"] | Should -BeExactly "John"
    }

    It "Ignores fields in PSCustomObject if specified" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $DataHash.AddIgnoreField('Age')
        $obj = [PSCustomObject]@{ Name = "John"; Age = 30 }
        $result = $DataHash._NormalizeDict($obj)

        $result.Keys | Should -BeExactly @('Name')  # "Age" should be excluded
        $result["Name"] | Should -BeExactly "John"
    }

    It "Normalizes nested dictionaries recursively" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $nestedDict = @{
            Outer = @{
                Inner2 = 200
                Inner1 = 100
            }
        }

        $result = $DataHash._NormalizeDict($nestedDict)
        $result["Outer"].Keys | Should -BeExactly @("Inner1", "Inner2")  # Sorted
        $result["Outer"]["Inner1"] | Should -BeExactly 100
        $result["Outer"]["Inner2"] | Should -BeExactly 200
    }

    It "Processes ordered nested dictionaries correctly" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $nestedOrdered = [ordered]@{
            Parent = [ordered]@{
                Y = 20
                X = 10
            }
        }

        $result = $DataHash._NormalizeDict($nestedOrdered)
        $result["Parent"].Keys | Should -BeExactly @("Y", "X")  # Order preserved
        $result["Parent"]["X"] | Should -BeExactly 10
        $result["Parent"]["Y"] | Should -BeExactly 20
    }

    It "Does not sort ordered dictionaries within unordered dictionaries" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $dict = @{
            OrderedPart = [ordered]@{ B = 2; A = 1 }
        }

        $result = $DataHash._NormalizeDict($dict)
        $result["OrderedPart"].Keys | Should -BeExactly @("B", "A")  # Order preserved
    }

    It "Handles null values correctly" {
        $DataHash = [DataHash]::New()
        $DataHash._resetVisited()
        $testDict = @{ Key1 = $null }
        $result = $DataHash._NormalizeDict($testDict)
        $result["Key1"] | Should -BeExactly "[NULL]"
    }
}
