using namespace LiteDB

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

class AlgorithmHelper {
    
    static [DataHashAlgorithmType] GetAlgorithmType([string]$name) {
        if ([Enum]::IsDefined([DataHashAlgorithmType], $name)) {
            return ([DataHashAlgorithmType]::$name).ToString()
        }

        Write-Host "Invalid Algorithm"
        [AlgorithmHelper]::PrintAlgorithmTypes()
        throw "`n Invalid Algorithm."
    }

    static [void] PrintAlgorithmTypes() {
        Write-Host "`n[DataHashAlgorithmType] - Available Algorithms:" -ForegroundColor Cyan
        Write-Host "---------------------------------" -ForegroundColor DarkCyan
        ([Enum]::GetValues([DataHashAlgorithmType])).ForEach({
            Write-Host $PSItem -ForegroundColor Green
        })
        Write-Host "---------------------------------`n" -ForegroundColor DarkCyan
    }
}

[NoRunspaceAffinity()]
Class DataHash {


    # Public Properties
    [string]$Hash
    [DataHashAlgorithmType]$HashAlgorithm = [DataHashAlgorithmType]::SHA256


    # Private Properties
    [string]$_hashAlgorithm = 'SHA256'
    [System.Collections.Generic.HashSet[string]]$_ignoreFields
    hidden [System.Collections.Generic.HashSet[Type]]$_typeMappers
    hidden [System.Collections.Generic.HashSet[object]]$_visited


    #1 Constructors

    # for when you want to configure the object before hashing
    DataHash() {
        try {
            $this._initializeIgnoreFields()
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $PSItem"
        }
    }

    # for when you want to accept the defaults
    DataHash([Object]$InputObject) {
        try {
            $this._initializeIgnoreFields()
            $this.Digest($InputObject)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $PSItem"
        }
    }

    # for when you want to configure Key Fields on Dict-Like objects from hash computation
    DataHash([Object]$InputObject, [object]$IgnoreFields) {
        try {
            [DataHash]::_isValidTypeForIgnores($InputObject)
            $this._initializeIgnoreFields()
            $this.AddIgnoreField($IgnoreFields)
            $this.Digest($InputObject)
        } catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $PSItem"
        }
    }

    DataHash([Object]$InputObject, [object]$IgnoreFields, [DataHashAlgorithmType]$Algorithm) {
        try {
            [DataHash]::_isValidTypeForIgnores($InputObject)
            $this._initializeIgnoreFields()
            $this.AddIgnoreField($IgnoreFields)
            $this._hashAlgorithm = $Algorithm.ToString()
            $this.Digest($InputObject)
        }
        catch {
            throw "[DataHash]::Constructor: Error while initializing DataHash - $PSItem"
        }
    }


    #2 Public Methods

    [DataHash] Digest([object]$InputObject) {
        $this._resetVisited()
        $this.Hash = $this._digest($InputObject)
        return $this
    }

    [DataHash] AddIgnoreField([string]$Ignore) {
        $this._ignoreFields.Add($Ignore)
        return $this
    }

    [DataHash] AddIgnoreField([System.Collections.Generic.IList[string]]$IgnoreFields) {
        $IgnoreFields.ForEach({$this._ignoreFields.Add($PSItem)})
        return $this
    }

    [System.Collections.Generic.HashSet[string]] GetIgnoreFields() {
        $return = [System.Collections.Generic.HashSet[string]]::new()
        $this._ignoreFields.ForEach({$return.Add($PSItem)})
        return $return
    }
    
    [System.Collections.Generic.HashSet[string]] GetLiveIgnoreFieldsInternalObject() {
        return $this._ignoreFields
    }

    [DataHash] RemoveIgnoreField([string]$Ignore) {
        $this._ignoreFields.Remove($Ignore)
        return $this
    }

    [DataHash] RemoveIgnoreField([System.Collections.Generic.IList[string]]$IgnoreFields) {
        $IgnoreFields.ForEach({$this._ignoreFields.Remove($PSItem)})
        return $this
    }
 
    [DataHash] SetAlgorithm([string]$Algorithm) {
        $this.Hash = $null
        $this._hashAlgorithm = [AlgorithmHelper]::GetAlgorithmType($Algorithm)
        return $this
    }

    [void] PrintAvailableAlgorithms() {
        [AlgorithmHelper]::PrintAlgorithmTypes()
    }


    #3 Private Methods

    ##4 Constructor Init Helpers


    hidden [void] _initializeIgnoreFields() {
        if ($null -eq $this._ignoreFields) {
            $this._ignoreFields = [System.Collections.Generic.HashSet[string]]::new()
        }
    }


    ##5 Public Method Helpers

    hidden [string] _digest([object]$InputObject) {
        $this._resetVisited()
        if ($null -eq $InputObject) { throw "[DataHash]::_hashObject: Input cannot be null." }

        if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [PSCustomObject]) {
                $normalizedDict = $this._normalizeDict($InputObject)
                return [DataHash]::_hash($normalizedDict, $this._hashAlgorithm)
        }

        if ([DataHash]::_isEnumerable($InputObject)) {
                $normalizedList = $this._normalizeList($InputObject)
                return [DataHash]::_hash($normalizedList, $this._hashAlgorithm)
            }
        
        if ([DataHash]::_isScalar($InputObject)) {
            return [DataHash]::_hash($InputObject, $this._hashAlgorithm)
        }

        throw "[DataHash]::Digest: Unsupported input type '$( $InputObject.GetType().FullName )'. A custom BSON serialization mapper may be required."
    }

    static hidden [bool] _isValidTypeForIgnores([object]$InputObject) {
        if ($InputObject -is [string] -or [System.Collections.Generic.IEnumerable[string]]) {
            return $true
        }
        else {
            throw "`$IgnoreFields must be either a single [string] or a flat collection of [string]."
        }
    }


    ##6 Normalization Methods

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
        foreach ($visitedItem in $this._visited) {
            if ([object]::ReferenceEquals($visitedItem, $Dictionary)) { 
                return "[CIRCULAR_REF]"
            }
        }
        
        $this._visited.Add($Dictionary)

        $normalizedDict = [Ordered]@{}

        if ($Dictionary -is [PSCustomObject]) {
            # Directly populate OrderedDictionary without extra copying
            foreach ($property in $Dictionary.PSObject.Properties | Sort-Object Name) {
                if (-not $this._ignoreFields.Contains($property.Name)) {
                    $normalizedDict[$property.Name] = $this._normalizeValue($property.Value)
                }
            }
            return $normalizedDict
        }

        $isOrdered = ($Dictionary -is [System.Collections.Specialized.OrderedDictionary]) -or
                    ($Dictionary -is [System.Collections.Generic.SortedDictionary[object,object]])

        $keys = if ($isOrdered) { $Dictionary.Keys } else { $Dictionary.Keys | Sort-Object { $PSItem.ToString() } }

        foreach ($key in $keys) {
            if (-not $this._ignoreFields.Contains($key)) {
                $normalizedDict[$key] = $this._normalizeValue($Dictionary[$key])
            }
        }

        return $normalizedDict
    }

    hidden [object] _normalizeList([object]$List) {
        try {
            if ([DataHash]::_CanFormCircularReferences($List)) {
                foreach ($visitedItem in $this._visited) {
                    if ([object]::ReferenceEquals($visitedItem, $List)) { 
                        return "[CIRCULAR_REF]"
                    }
                }
                $this._visited.Add($List)
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
                $normalizedList = $normalizedList | Sort-Object { $PSItem.ToString() }
            }

            return $normalizedList
        }
        catch {
            $exception = $PSItem.Exception
            Write-Host "Exception Type: $($exception.GetType().FullName)"
            Write-Host "Message: $($exception.Message)"
            Write-Host "Stack Trace:`n$($exception.StackTrace)"
            throw $PSItem
        }
    }

    static hidden [string] _normalizeFloat([double]$Value) {
        return $Value.ToString("R", [System.Globalization.CultureInfo]::InvariantCulture)
    }


    ##7 Normaalization Helpers

    hidden [void] _resetVisited() {
        if ($null -eq $this._visited) {
            $this._visited = [System.Collections.Generic.HashSet[object]]::new()
        } else {
            $this._visited.Clear()
        }
    }

    static hidden [bool] _isScalar([object]$Value) {
        return $Value -is [ValueType] -or $Value -is [string]
    }

    static hidden [bool] _isEnumerable([object]$Value) {
        return ($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])
    }

    static hidden [bool] _CanFormCircularReferences([object]$Value) {
        return ($Value -is [System.Collections.IEnumerable]) -and
            ($Value -isnot [string]) -and
            ($Value -isnot [System.Array]) -and
            ($Value -isnot [System.Collections.Generic.HashSet[object]]) -and
            ($Value -isnot [System.Collections.Generic.SortedSet[object]])
    }

    static hidden [bool] _CanSerializeToBSON([object]$Value) {
        if ($null -eq $Value) { return $true }  # Null is valid BSON (`null`)

        # Directly serializable types
        if ($Value -is [System.Collections.IDictionary] -or
            $Value -is [PSCustomObject] -or
            $Value -is [System.Collections.Specialized.OrderedDictionary]) {
            return $true  # Already a BSON document
        }

        # Scalars (but must be wrapped)
        if ($Value -is [ValueType] -or $Value -is [string]) {
            return $false  # Must be wrapped
        }

        # Lists (but must be wrapped)
        if ($Value -is [System.Collections.IEnumerable]) {
            return $false  # Must be wrapped
        }

        # If it's a complex .NET object with properties, assume it can be serialized
        return $true
    }


    #8 Hashing Methods

    static hidden [object] _hash ([object]$InputObject, [string]$Algorithm){

        $dict = $null

        if (-not [DataHash]::_CanSerializeToBSON($InputObject)) {
            $dict = @{_value = $InputObject}
        }
        else {
            $dict = $InputObject
        }

        $memStream = [System.IO.MemoryStream]::new()
        [DataHash]::_serializeToBsonStream($memStream, $dict)
        $memStream.Position = 0
        return [DataHash]::_computeHash_Streaming($memStream, $Algorithm)
    }

    static hidden [void] _serializeToBsonStream([System.IO.Stream]$Stream, [object]$InputObject) {
        if ($null -eq $InputObject) { throw "[DataHash]::_serializeToBsonStream: Input cannot be null." }

        # Ensure PowerShell object is correctly mapped to BSON format
        $bsonDocument = [BsonMapper]::Global.ToDocument($InputObject)

        # Serialize BsonDocument to Byte Array
        $serializedBytes = [BsonSerializer]::Serialize($bsonDocument)

        # Write the byte array to the stream
        $Stream.Write($serializedBytes, 0, $serializedBytes.Length)
        $Stream.Flush()  # Ensure all data is written
    }

    static hidden [string] _computeHash_Streaming([System.IO.Stream]$Stream, [string]$Algorithm) {
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


    #9 Operator Overrides

    [bool] Equals([object]$Other) {
        if ($Other -is [DataHash]) {
            return [DataHash]::op_Equality($this, $Other)
        }
        if ($Other -is [string]) {
            return $this.Hash -eq $Other
        }
        return $false
    }

    static [bool] op_Equality([DataHash]$a, [DataHash]$b) {
        if ($null -eq $a -or $null -eq $b) { return $false }
        return $a.Hash -eq $b.Hash
    }

    static [bool] op_Equality([DataHash]$a, [string]$b) {
        if ($null -eq $a) { return $false }
        return $a.Hash -eq $b
    }

    static [bool] op_Equality([string]$a, [DataHash]$b) {
        if ($null -eq $b) { return $false }
        return $a -eq $b.Hash
    }

    static [bool] op_Inequality([DataHash]$a, [DataHash]$b) {
        return -not ([DataHash]::op_Equality($a, $b))
    }

    static [bool] op_Inequality([DataHash]$a, [string]$b) {
        return -not ([DataHash]::op_Equality($a, $b))
    }

    static [bool] op_Inequality([string]$a, [DataHash]$b) {
        return -not ([DataHash]::op_Equality($a, $b))
    }


    #10 Operator Override Helper overrides

    [int] GetHashCode() {
        return $this.Hash.GetHashCode()
    }

    [string] ToString() {
        return $this.Hash
    }
}