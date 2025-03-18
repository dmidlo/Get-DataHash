using assembly 'LiteDB.dll'
using namespace LiteDB
using module './private/types/DataHash.psm1'

try {
    $mapper = [BsonMapper]::Global
    $Mappers = Get-ChildItem -Path "$PSScriptRoot\private\types\Mappers" -Filter "Mapper_*.ps1"

    foreach ($script in $Mappers) {
        . $script.FullName
    }
    write-host "Mappers Registered Succesfully"
}
catch {
    write-host "Custom Mappers not registered.  Default types support for serialization will be used."
}


# Define the types to export with type accelerators.
$ExportableTypes =@(
    [DataHash], [DataHashAlgorithmType]
)
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator '$($Type.FullName)'"
            'Accelerator already exists.'
        ) -join ' - '

throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            'TypeAcceleratorAlreadyExists',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}
# Add type accelerators for every exportable type.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()