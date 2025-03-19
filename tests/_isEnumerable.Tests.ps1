Import-Module Pester
Import-Module './Get-DataHash.psd1'

Describe "DataHash::_IsEnumerable" {
    
    It "Should return `$true for an array" {
        $result = [DataHash]::_IsEnumerable(@(1,2,3))
        $result | Should -BeTrue
    }

    It "Should return `$true for a list (System.Collections.Generic.List[object])" {
        $list = [System.Collections.Generic.List[object]]::new()
        $list.Add(1)
        $list.Add(2)
        $result = [DataHash]::_IsEnumerable($list)
        $result | Should -BeTrue
    }

    It "Should return `$true for a Queue" {
        $queue = [System.Collections.Queue]::new()
        $queue.Enqueue("A")
        $queue.Enqueue("B")
        $result = [DataHash]::_IsEnumerable($queue)
        $result | Should -BeTrue
    }

    It "Should return `$true for a Stack" {
        $stack = [System.Collections.Stack]::new()
        $stack.Push(10)
        $stack.Push(20)
        $result = [DataHash]::_IsEnumerable($stack)
        $result | Should -BeTrue
    }

    It "Should return `$true for a Hashtable" {
        $hashtable = @{ Key1 = "Value1"; Key2 = "Value2" }
        $result = [DataHash]::_IsEnumerable($hashtable)
        $result | Should -BeTrue
    }

    It "Should return `$false for a PSCustomObject with multiple properties" {
        $psObj = [PSCustomObject]@{ Name = "Test"; Age = 30 }
        $result = [DataHash]::_IsEnumerable($psObj)
        $result | Should -BeFalse
    }

    It "Should return `$false for a string" {
        $result = [DataHash]::_IsEnumerable("Hello, World!")
        $result | Should -BeFalse
    }

    It "Should return `$false for an integer" {
        $result = [DataHash]::_IsEnumerable(42)
        $result | Should -BeFalse
    }

    It "Should return `$false for a boolean value" {
        $result = [DataHash]::_IsEnumerable($true)
        $result | Should -BeFalse
    }

    It "Should return `$false for a single object instance (non-enumerable)" {
        $obj = New-Object PSObject -Property @{ Key = "Value" }
        $result = [DataHash]::_IsEnumerable($obj)
        $result | Should -BeFalse
    }

    It "Should return '`$false' for '`$null'" {
        $result = [DataHash]::_IsEnumerable($null)
        $result | Should -BeFalse
    }
}
