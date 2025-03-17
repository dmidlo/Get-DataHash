$mapper = [LiteDB.BsonMapper]::Global

$Mappers = Get-ChildItem -Path ".\private\types\Mappers\" -Filter "Mapper_*.ps1"

# Dot-source each mapper script
foreach ($mapperScript in $mappers) {
    . $mapperScript.FullName
}

Write-Host "All mappers registered successfully."
