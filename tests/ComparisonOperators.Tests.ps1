Import-Module Pester
Import-Module './Get-DataHash.psd1'

Describe "DataHash Comparison Operators" {

    BeforeAll {
        $obj1 = @{ A = 1; B = 2 }
        $obj2 = @{ A = 1; B = 2 }
        $obj3 = @{ A = 2; B = 3 }

        $hash1 = [DataHash]::new($obj1)
        $hash2 = [DataHash]::new($obj2)
        $hash3 = [DataHash]::new($obj3)
    }

    It "Two identical DataHash objects should be equal" {
        $hash1 | Should -Be $hash2
    }

    It "Different objects should produce different hashes" {
        $hash1 | Should -Not -Be $hash3
    }

    It "Comparison with raw hash string should work" {
        $hash1 | Should -Be $hash1.Hash
    }

    It "Equality comparison with null should return false" {
        $hash1 | Should -Not -Be $null
    }

    It "Inequality operator should return correct results" {
        ($hash1 -ne $hash2) | Should -Be $false  # Should be equal
        ($hash1 -ne $hash3) | Should -Be $true   # Different objects
    }
}
