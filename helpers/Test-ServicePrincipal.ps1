# This is a basic test to see if it is possible to connect to Azure using a service principals
#
# It assumes the following environment vars are set (same as used by Terraform):
#
#$env:ARM_TENANT_ID
#$env:ARM_SUBSCRIPTION_ID
#$env:ARM_CLIENT_ID
#$env:ARM_CLIENT_SECRET
#
$password = $env:ARM_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force
$credentials = [PSCredential]::new($env:ARM_CLIENT_ID,$password)
try {
    $connection = Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
    if ($connection)    
    {
        Write-Host ("Connected to subscription: {0}" -f $connection.context.subscription.name)

        try {
            $rg = (Get-AzResourceGroup -ErrorAction SilentlyContinue)
            if ($rg){
                Write-Host ("This principal found one or more resource groups named: {0}" -f ($rg.ResourceGroupName).Split(","))               
            }
            else {
                Write-Warning "At least one resource group was expected but none were returned."
            }
        }
        catch {
            Write-Error ("There was an error retrieving resource groups {0}") -f $_.Exception
        }
    }
}
catch {
    Write-Error "There was an error connecting to the subscriptionId '{0}' in tenantid '{1}'.  Error: {2}" -f $env:ARM_SUBSCRIPTION_ID,$env:ARM_TENANT_ID,$_.Exception
}
finally {
    # remove the AzureRMContext.json file
    $AzureRMContext = "$env:userprofile\.azure\AzureRmContext.json"
    if (Test-Path($AzureRMContext))
    {
        Remove-Item $AzureRMContext -Force
        Write-Host "Removed AzureRmContext.json file."        
    }
}

