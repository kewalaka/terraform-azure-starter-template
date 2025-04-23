function Grant-RBACAdministratorRole {
  param(
      [string]$ObjectId,
      [string]$Scope,
      [string]$RoleDefinitionName,
      [string]$ManagedIdentityName
  )

  try {
      $ra = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionName $RoleDefinitionName
  }
  catch {}
  if ($null -eq $ra) {
      New-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionName $RoleDefinitionName | Out-Null
      Write-Host "✔ Role '$RoleDefinitionName' granted to managed identity '$ManagedIdentityName' at scope '$Scope'"
  }
  else {
      Write-Host "✔ Role '$RoleDefinitionName' already exists for identity '$ManagedIdentityName' at scope '$Scope'"
  }
}