try {
    $mapper.RegisterType([DataHash],
        # Serialize DataHash to BSON
        {
            param([DataHash] $value)
            if ($null -eq $value) { return $null }

            $doc = [LiteDB.BsonDocument]::new()
            $doc["Hash"] = $value.Hash
            $doc["HashAlgorithm"] = $value.HashAlgorithm.ToString()
            return $doc
        },
        # Deserialize BSON back into DataHash
        {
            param([LiteDB.BsonValue] $bson)
            if ($null -eq $bson) { return $null }

            $doc = $bson.AsDocument
            $hash = $doc["Hash"].AsString
            $hashAlgorithm = [DataHashAlgorithmType]::Parse([DataHashAlgorithmType], $doc["HashAlgorithm"].AsString)

            $obj = [DataHash]::new()
            $obj.Hash = $hash
            $obj.HashAlgorithm = $hashAlgorithm
            return $obj
        }
    )
}
catch {
    throw $_
}