Import-Module Pester
Import-Module './Get-DataHash.psm1'

Describe "DataHash::_normalizeFloat" {
    It "should return a valid byte representation for a positive float" {
        $result = [DataHash]::_normalizeFloat(3.1415926535)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]3.1415926535))
        $result | Should -BeExactly $expected
    }

    It "should return a valid byte representation for a negative float" {
        $result = [DataHash]::_normalizeFloat(-2.7182818284)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]-2.7182818284))
        $result | Should -BeExactly $expected
    }

    It "should return a valid byte representation for zero (0.0)" {
        $result = [DataHash]::_normalizeFloat(0.0)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]0.0))
        $result | Should -BeExactly $expected
    }

    It "should return a valid byte representation for a very small number (close to zero)" {
        $result = [DataHash]::_normalizeFloat(1.0e-10)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]1.0e-10))
        $result | Should -BeExactly $expected
    }

    It "should return a valid byte representation for a large number" {
        $result = [DataHash]::_normalizeFloat(1.0e10)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]1.0e10))
        $result | Should -BeExactly $expected
    }

    It "should return the correct representation for Infinity" {
        $result = [DataHash]::_normalizeFloat([double]::PositiveInfinity)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]::PositiveInfinity))
        $result | Should -BeExactly $expected
    }

    It "should return the correct representation for -Infinity" {
        $result = [DataHash]::_normalizeFloat([double]::NegativeInfinity)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]::NegativeInfinity))
        $result | Should -BeExactly $expected
    }

    It "should return the correct representation for NaN (Not-a-Number)" {
        $result = [DataHash]::_normalizeFloat([double]::NaN)
        $expected = [BitConverter]::ToString([BitConverter]::GetBytes([double]::NaN))
        $result | Should -BeExactly $expected
    }

    It "should consistently return the same result for the same input value" {
        $input = 123.456
        $result1 = [DataHash]::_normalizeFloat($input)
        $result2 = [DataHash]::_normalizeFloat($input)
        $result1 | Should -BeExactly $result2
    }
}
