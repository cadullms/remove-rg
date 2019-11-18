[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory=$true)] $ResourceGroupName
)

.$PSScriptRoot\Remove-RgAndAssociatedObjects.Implementation.ps1

Remove-RgAndAssociatedObjects -ResourceGroupName $ResourceGroupName -Confirm:$ConfirmPreference -WhatIf:$WhatIfPreference