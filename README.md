# Introduction 

## Azure service principal setup

Check out 'New-ServicePrincipal.ps1', this code will create a resource group (RG) for your deployment & the service principal scoped to this RG.

## Local development environment

See these [instructions](/docs/Setup%20a%20local%20dev%20environment.md) for how to set up a local development environment.

## Updating Terraform versions

Main.tf includes logic to pin to a specific version of Terraform and providers in use (AzureRM & AzureAD).