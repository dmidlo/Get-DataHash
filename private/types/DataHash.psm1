
# Load DLL first
$LiteDBPath = [System.IO.Path]::Combine("private", "types", "LiteDB.dll")
$ImportPrivateModulesPath = [System.IO.Path]::Combine("private", "Import-PrivateModules.ps1")

if (-Not (([System.AppDomain]::CurrentDomain.GetAssemblies()).Where({ $_.Location -eq $assemblyPath }))) {
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

enum DataHashAlgorithmType {
    MD5
    SHA1
    SHA256
    SHA384
    SHA512
}

[NoRunspaceAffinity()]
Class DataHash {
    [string]$Hash
    [System.Collections.Generic.HashSet[string]]$IgnoreFields
    [DataHashAlgorithmType]$HashAlgorithm = [DataHashAlgorithmType]::SHA256
    hidden [System.Collections.Generic.HashSet[object]]$Visited

    DataHash() {
        try {
            $this.ResetVisited()
            $this.InitializeIgnoreFields()
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    DataHash(
        [Object]$InputObject
    ) {
        try {
            $this.ResetVisited()
            $this.InitializeIgnoreFields()
            $this.Hash = $this.Generate($InputObject, [DataHashAlgorithmType]::SHA256)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    DataHash(
        [Object]$InputObject,
        [System.Collections.Generic.HashSet[string]]$IgnoreFields
    ) {
        try {
            $this.ResetVisited()
            $this.IgnoreFields = $IgnoreFields
            $this.Hash = $this.Generate($InputObject, [DataHashAlgorithmType]::SHA256)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    DataHash(
        [Object]$InputObject,
        [System.Collections.Generic.HashSet[string]]$IgnoreFields, 
        [DataHashAlgorithmType]$HashAlgorithm
    ) { 
        try {
            $this.ResetVisited()
            $this.IgnoreFields = $IgnoreFields
            $this.Hash = $this.Generate($InputObject, $HashAlgorithm)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $_"
        }
    }

    hidden [string] Generate(
        [object]$InputObject, 
        [DataHashAlgorithmType]$HashAlgorithm 
    ) {
        $this.ResetVisited()
        if ($null -eq $InputObject) { throw "[DataHash]::_hashObject: Input cannot be null." }
        
        $memStream = [System.IO.MemoryStream]::new()

        if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [PSCustomObject]) {
                $normalizedDict = $this._normalizeDict($InputObject)
                
                [DataHash]::_serializeToBsonStream($memStream, $normalizedDict)
                $memStream.Position = 0
                return [DataHash]::_computeHash_Streaming($memStream, $this.HashAlgorithm)
        }

        if ([DataHash]::_isEnumerable($InputObject)) {
                $normalizedList = $this._normalizeList($InputObject)
            
                [DataHash]::_serializeToBsonStream($memStream, $normalizedList)
                $memStream.Position = 0
                return [DataHash]::_computeHash_Streaming($memStream, $this.HashAlgorithm)
            }
        
        if ([DataHash]::_isScalar($InputObject)) {
            [DataHash]::_serializeToBsonStream($memStream, $InputObject)
            $memStream.Position = 0
            return [DataHash]::_computeHash_Streaming($memStream, $this.HashAlgorithm)
        }

        throw "[DataHash]::Generate: Unsupported input type '$( $InputObject.GetType().FullName )'. A custom BSON serialization mapper may be required."
    }

    hidden [object] _normalizeValue([object]$Value) {
        if ($null -eq $Value) { return "[NULL]" }

        if ([DataHash]::_isScalar($Value)) {
            if ($Value -is [double] -or $Value -is [float]) {
                return [DataHash]::_normalizeFloat($Value)
            }
            return $Value
        }

        if ($Value -is [System.Collections.IDictionary] -or $Value -is [PSCustomObject]) {
            return $this._normalizeDict($Value)
        }

        if ([DataHash]::_isEnumerable($Value)) {
            return $this._normalizeList($Value)
        }

        # If an unsupported type sneaks in here, provide a clear placeholder:
        return "[UNSUPPORTED_TYPE:$($Value.GetType().FullName)]"
    }

    hidden [object] _normalizeDict([object]$Dictionary) {
        foreach ($visitedItem in $this.Visited) {
            if ([object]::ReferenceEquals($visitedItem, $Dictionary)) { 
                return "[CIRCULAR_REF]"
            }
        }

        $this.Visited.Add($Dictionary)

        $isOrdered = ($Dictionary -is [System.Collections.Specialized.OrderedDictionary]) -or
                    ($Dictionary -is [System.Collections.Generic.SortedDictionary[object,object]])

        $normalizedDict = [Ordered]@{}

        if ($Dictionary -is [PSCustomObject]) {
            $tempDict = @{}
            foreach ($property in $Dictionary.PSObject.Properties | Sort-Object Name) {
                if (-not $this.IgnoreFields.Contains($property.Name)) {
                    $tempDict[$property.Name] = $property.Value
                }
            }
            $Dictionary = $tempDict
        }

        $keys = if ($isOrdered) { $Dictionary.Keys } else { $Dictionary.Keys | Sort-Object { $_.ToString() } }

        foreach ($key in $keys) {
            if (-not $this.IgnoreFields.Contains($key)) {
                $normalizedDict[$key] = $this._normalizeValue($Dictionary[$key])
            }
        }

        return $normalizedDict
    }

    hidden [object] _normalizeList([object]$List) {
        try {
            if ([DataHash]::_CanFormCircularReferences($List)) {
                foreach ($visitedItem in $this.Visited) {
                    if ([object]::ReferenceEquals($visitedItem, $List)) { 
                        return "[CIRCULAR_REF]"
                    }
                }
                $this.Visited.Add($List)
            }


            $isOrdered = ($List -is [System.Collections.IList]) -or
                        ($List -is [System.Collections.Generic.Queue[object]]) -or
                        ($List -is [System.Collections.Generic.Stack[object]])

            $normalizedList = [System.Collections.ArrayList]::new()

            foreach ($item in $List) {
                $normalizedItem = $this._normalizeValue($item)
        
                $normalizedList.Add($normalizedItem)
            }

            # Sort only if unordered
            if (-not $isOrdered) {
                $normalizedList = $normalizedList | Sort-Object { $_.ToString() }
            }

            return $normalizedList
        }
        catch {
            $exception = $_.Exception
            Write-Host "Exception Type: $($exception.GetType().FullName)"
            Write-Host "Message: $($exception.Message)"
            Write-Host "Stack Trace:`n$($exception.StackTrace)"
            throw
        }
    }

    static hidden [string] _normalizeFloat([double]$Value) {
        return $Value.ToString("G17", [System.Globalization.CultureInfo]::InvariantCulture)
    }

    static hidden [void] _serializeToBsonStream(
        [System.IO.Stream]$Stream,
        [object]$InputObject
    ) {
        if ($null -eq $InputObject) { throw "[DataHash]::_serializeToBsonStream: Input cannot be null." }

        # Ensure PowerShell object is correctly mapped to BSON format
        $bsonDocument = [LiteDB.BsonMapper]::Global.ToDocument($InputObject)

        # Serialize BsonDocument to Byte Array
        $serializedBytes = [LiteDB.BsonSerializer]::Serialize($bsonDocument)

        # Write the byte array to the stream
        $Stream.Write($serializedBytes, 0, $serializedBytes.Length)
        $Stream.Flush()  # Ensure all data is written
    }


    static hidden [string] _computeHash_Streaming(
        [System.IO.Stream]$Stream,
        [DataHashAlgorithmType]$Algorithm
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
        $hasher.TransformFinalBlock([byte[]]::new(0), 0, 0)

        # Convert hash to hexadecimal string
        return [BitConverter]::ToString($hasher.Hash) -replace '-', ''
    }

    static hidden [bool] _isEnumerable(
        [object]$Value
    ) {
        return ($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])
    }

    static hidden [bool] _isScalar([object]$Value) {
        return $Value -is [ValueType] -or $Value -is [string]
    }

    static hidden [bool] _CanFormCircularReferences([object]$Value) {
        return ($Value -is [System.Collections.IEnumerable]) -and
            ($Value -isnot [string]) -and
            ($Value -isnot [System.Array]) -and
            ($Value -isnot [System.Collections.Generic.HashSet[object]]) -and
            ($Value -isnot [System.Collections.Generic.SortedSet[object]])
    }

    hidden [void] ResetVisited() {
        if ($null -eq $this.Visited) {
            $this.Visited = [System.Collections.Generic.HashSet[object]]::new()
        } else {
            $this.Visited.Clear()
        }
    }

    hidden [void] InitializeIgnoreFields() {
        if ($null -eq $this.IgnoreFields) {
            $this.IgnoreFields = [System.Collections.Generic.HashSet[string]]::new()
        } else {
            $this.IgnoreFields.Clear()
        }
    }


    [bool] Equals(
        [object]$Other
    ) {
        if ($Other -is [DataHash]) {
            return $this.op_Equality($this, $Other)
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