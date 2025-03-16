
# Load DLL first
$LiteDBPath = [System.IO.Path]::Combine("private", "types", "LiteDB.dll")
$ImportPrivateModulesPath = [System.IO.Path]::Combine("private", "Import-PrivateModules.ps1")

if (-Not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Location -eq $assemblyPath })) {
    Add-Type -Path $LiteDBPath
}

# Dot-source imports to apply 'using namespace'
. $ImportPrivateModulesPath

<#
.SYNOPSIS
    A PowerShell class for generating deterministic hashes of objects.

.DESCRIPTION
    - Computes a hash from complex objects, preserving structural and value integrity.
    - Supports nested objects, lists, and dictionaries while handling circular references.
    - Implicitly respects ordering for ordered collections (e.g., [ordered]@{}, List, Queue, Stack).
    - Sorts unordered collections (e.g., Hashtable, Dictionary) for stable hashing.
    - Provides field exclusion for selective hashing.
    - Uses SHA256 by default but supports configurable hash algorithms.
#>

[NoRunspaceAffinity()]
Class DataHash {
    [string]$Hash

    DataHash(
        [Object]$InputObject
    ) {
        try {
            $IgnoreFields = [System.Collections.Generic.HashSet[string]]::new()
            $this.Hash = [DataHash]::Normalize($InputObject, $IgnoreFields, "SHA256")
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    DataHash(
        [Object]$InputObject,
        [System.Collections.Generic.HashSet[string]]$IgnoreFields
    ) {
        try {
            $this.Hash = [DataHash]::Normalize($InputObject, $IgnoreFields, "SHA256")
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    DataHash(
        [Object]$InputObject,
        [System.Collections.Generic.HashSet[string]]$IgnoreFields, 
        [string]$HashAlgorithm
    ) {
        try {
            $this.Hash = [DataHash]::Normalize($InputObject, $IgnoreFields, $HashAlgorithm)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    static hidden [string] Normalize(
        [object]$InputObject, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields, 
        [string]$HashAlgorithm = "SHA256"
    ) {
        return [DataHash]::_hashObject($InputObject, $IgnoreFields, $HashAlgorithm)
    }

    static hidden [string] _hashObject(
        [object]$InputObject, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields,
        [string]$HashAlgorithm
    ) {
        if ($null -eq $InputObject) { throw "[DataHash]::_hashObject: Input cannot be null." }

        $visited = [System.Collections.Generic.HashSet[object]]::new()

        if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [PSCustomObject]) {
            return [DataHash]::_hashDict($InputObject, $IgnoreFields, $HashAlgorithm, $visited)
        }

        if ([DataHash]::_isEnumerable($InputObject)) {
            return [DataHash]::_hashList($InputObject, $IgnoreFields, $HashAlgorithm, $visited)
        }

        return [DataHash]::_computeHash_Streaming($InputObject.ToString(), $HashAlgorithm)
    }

    static hidden [string] _hashDict(
        [object]$Dictionary, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields,
        [string]$HashAlgorithm,
        [System.Collections.Generic.HashSet[object]]$Visited
    ) {
        $normalizedDict = [DataHash]::_normalizeDict($Dictionary, $IgnoreFields, "", $Visited)
        
        $memStream = [System.IO.MemoryStream]::new()
        [DataHash]::_serializeToBsonStream($memStream, $normalizedDict)
        $memStream.Position = 0
        return [DataHash]::_computeHash_Streaming($memStream, $HashAlgorithm)
    }

    static hidden [object] _normalizeDict(
        [object]$Dictionary, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields,
        [string]$ParentPath = "",
        [System.Collections.Generic.HashSet[object]]$Visited
    ) {
        if ($Visited.Contains($Dictionary)) { return "[CIRCULAR_REF]" }
        $Visited.Add($Dictionary)

        $isOrdered = ($Dictionary -is [ordered]) -or
                    ($Dictionary -is [System.Collections.Specialized.OrderedDictionary]) -or
                    ($Dictionary -is [System.Collections.Generic.SortedDictionary[object,object]])

        $normalizedDict = if ($isOrdered) { [ordered]@{} } else { @{} }

        # Convert PSCustomObject to Dictionary
        if ($Dictionary -is [PSCustomObject]) {
            $Dictionary = $Dictionary.PSObject.Properties |
                        Sort-Object Name |  # Ensure deterministic order
                        Where-Object { -not $IgnoreFields.Contains($_.Name) } | 
                        ForEach-Object { @{ $_.Name = $_.Value } }
        }

        # Process Keys in Deterministic Order
        $keys = if ($isOrdered) { $Dictionary.Keys } else { $Dictionary.Keys | Sort-Object { $_.ToString() } }

        foreach ($key in $keys) {
            if (-not $IgnoreFields.Contains($key)) {
                $currentPath = if ($ParentPath -eq "") { $key } else { "$ParentPath.$key" }
                $normalizedDict[$key] = [DataHash]::_normalizeValue($Dictionary[$key], $IgnoreFields, $currentPath, $Visited)
            }
        }

        return $normalizedDict
    }


    static hidden [object] _normalizeList(
        [object]$List, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields,
        [string]$ParentPath = "",
        [System.Collections.Generic.HashSet[object]]$Visited
    ) {
        if ($Visited.Contains($List)) { return "[CIRCULAR_REF]" }
        $Visited.Add($List)

        $isOrdered = ($List -is [System.Collections.IList]) -or
                    ($List -is [System.Collections.Generic.Queue[object]]) -or
                    ($List -is [System.Collections.Generic.Stack[object]])

        $normalizedList = @()

        foreach ($item in $List) {
            $normalizedList += [DataHash]::_normalizeValue($item, $IgnoreFields, $ParentPath, $Visited)
        }

        # Sort only if unordered
        if (-not $isOrdered) {
            $normalizedList = $normalizedList | Sort-Object { $_.ToString() }
        }

        return $normalizedList
    }

    static hidden [object] _normalizeValue(
        [object]$Value, 
        [System.Collections.Generic.HashSet[string]]$IgnoreFields,
        [string]$ParentPath = "",
        [System.Collections.Generic.HashSet[object]]$Visited
    ) {
        if ($null -eq $Value) { return "[NULL]" }
        if ($Value -is [System.Collections.IDictionary] -or $Value -is [PSCustomObject]) {
            return [DataHash]::_normalizeDict($Value, $IgnoreFields, $ParentPath, $Visited)
        }
        if ([DataHash]::_isEnumerable($Value)) {
            return [DataHash]::_normalizeList($Value, $IgnoreFields, $ParentPath, $Visited)
        }
        if ($Value -is [double] -or $Value -is [float]) {
            return [DataHash]::_normalizeFloat($Value)
        }
        return $Value
    }

    static hidden [string] _normalizeFloat(
        [double]$Value
    ) {
        return [BitConverter]::ToString([BitConverter]::GetBytes($Value))
    }

    static hidden [void] _serializeToBsonStream(
        [System.IO.Stream]$Stream,
        [object]$InputObject
    ) {
        if ($null -eq $InputObject) { throw "[DataHash]::_serializeToBsonStream: Input cannot be null." }

        # Ensure PowerShell object is correctly mapped to BSON format
        $bsonDocument = [LiteDB.BsonMapper]::Global.ToDocument($InputObject)

        # Create a BinaryWriter to stream BSON data
        $binaryWriter = [System.IO.BinaryWriter]::new($Stream)

        # Serialize BSON Document to Stream
        [LiteDB.BsonSerializer]::Serialize($binaryWriter, $bsonDocument)

        # Ensure buffer is flushed
        $binaryWriter.Flush()
    }

    static hidden [string] _computeHash_Streaming(
        [System.IO.Stream]$Stream,
        [string]$Algorithm
    ) {
        $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        if ($null -eq $hasher) { throw "[DataHash]::_computeHash_Streaming: Invalid hash algorithm '$Algorithm'" }

        # Reset stream position to ensure we start from the beginning
        $Stream.Position = 0  

        # Allocate a buffer for streaming
        $bufferSize = 4096  # 4KB blocks (adjust for efficiency)
        $buffer = [byte[]]::new($bufferSize)

        # Process Stream in Chunks
        while (($bytesRead = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $hasher.TransformBlock($buffer, 0, $bytesRead, $buffer, 0)
        }

        # Finalize Hash Computation
        $hasher.TransformFinalBlock(@(), 0, 0)

        # Convert hash to hexadecimal string
        return [BitConverter]::ToString($hasher.Hash) -replace '-', ''
    }

    static hidden [bool] _isEnumerable(
        [object]$Value
    ) {
        return ($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])
    }

    [bool] Equals(
        [object]$Other
    ) {
        if ($Other -is [DataHash]) {
            return [DataHash]::op_Equality($this, $Other)
        }
        if ($Other -is [string]) {
            return $this.Hash -eq $Other
        }
        return $false
    }

    static [bool] op_Equality(
        [DataHash]$a,
        [DataHash]$b
    ) {
        if ($null -eq $a -or $null -eq $b) { return $false }
        return $a.Hash -eq $b.Hash
    }

    static [bool] op_Inequality(
        [DataHash]$a, 
        [DataHash]$b
    ) {
        return -not ([DataHash]::op_Equality($a, $b))
    }

    static [bool] op_Equality(
        [DataHash]$a, 
        [string]$b
    ) {
        if ($null -eq $a) { return $false }
        return $a.Hash -eq $b
    }

    static [bool] op_Equality(
        [string]$a, 
        [DataHash]$b
    ) {
        if ($null -eq $b) { return $false }
        return $a -eq $b.Hash
    }

    static [bool] op_Inequality(
        [DataHash]$a, 
        [string]$b
    ) {
        return -not ([DataHash]::op_Equality($a, $b))
    }

    static [bool] op_Inequality(
        [string]$a, 
        [DataHash]$b
    ) {
        return -not ([DataHash]::op_Equality($a, $b))
    }

    [int] GetHashCode() {
        return $this.Hash.GetHashCode()
    }

    [string] ToString() {
        return $this.Hash
    }
}