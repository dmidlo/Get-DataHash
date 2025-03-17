Import-Module Pester
Import-Module './Get-DataHash.psm1'

Describe "DataHash Constructors" {

    BeforeAll {
        # Sample Data
        $simpleObject = @{ Name = "John"; Age = 30 }
        $complexObject = @{
            User = @{
                Name = "Alice"
                Details = @{ ID = 123; Email = "alice@example.com" }
            }
            Roles = @("Admin", "Editor")
        }
        $ignoreFields = [System.Collections.Generic.HashSet[string]]::new()
        $ignoreFields.Add("Age")
    }

    It "Default constructor should initialize with expected defaults" {
        $hashObj = [DataHash]::new()
        $hash = $hashObj.Generate($simpleObject, [DataHashAlgorithmType]::SHA256)
        $hash | Should -Not -BeNullOrEmpty
        $hashObj | Should -BeOfType [DataHash]
        $hashObj.HashAlgorithm | Should -Be 'SHA256'
    }

    It "Constructor with object should generate a valid hash" {
        $hashObj = [DataHash]::new($simpleObject)
        $hashObj | Should -Not -BeNullOrEmpty
        $hashObj.Hash | Should -Match "^[0-9A-Fa-f]{64}$"  # Assuming SHA256 default
    }

    It "Constructor with object and ignore fields should exclude specified fields" {
        $hash1 = [DataHash]::new($simpleObject)
        $hash2 = [DataHash]::new($simpleObject, $ignoreFields)

        $hash1.Hash | Should -Not -Be $hash2.Hash  # Should be different due to ignored field
    }

    It "Constructor with object, ignore fields, and algorithm should apply correct hashing" {
        $hashMD5 = [DataHash]::new($simpleObject, $ignoreFields, [DataHashAlgorithmType]::MD5)
        $hashSHA512 = [DataHash]::new($simpleObject, $ignoreFields, [DataHashAlgorithmType]::SHA512)

        $hashMD5.Hash | Should -Match "^[0-9A-Fa-f]{32}$"   # MD5 = 32 hex chars
        $hashSHA512.Hash | Should -Match "^[0-9A-Fa-f]{128}$" # SHA512 = 128 hex chars
    }

    It "Constructor should handle null input gracefully" {
        { [DataHash]::new($null) } | Should -Throw -ErrorId '*Input cannot be null*'
    }

    It "Constructor should handle empty dictionaries" {
        $hashEmptyDict = [DataHash]::new(@{})
        $hashEmptyDict.Hash | Should -Not -BeNullOrEmpty
    }

    It "Constructor should handle empty objects and collections" {
        $hashEmptyArray = [DataHash]::new(@())
        $hashEmptyArray.Hash | Should -Not -BeNullOrEmpty
    }

    It "Handles complex nested objects correctly" {
        $hashComplex1 = [DataHash]::new($complexObject)
        $hashComplex2 = [DataHash]::new($complexObject)

        $hashComplex1.Hash | Should -Be $hashComplex2.Hash  # Same data, should match
    }

    It "Detects circular references and does not crash" {
        $circularObject = @{ Name = "Bob" }
        $circularObject["Self"] = $circularObject  # Introduce circular reference

        { [DataHash]::new($circularObject) } | Should -Not -Throw
    }
}
