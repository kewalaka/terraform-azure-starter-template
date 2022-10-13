Terraform (Dev) Plan: [![Build Status](https://dev.azure.com/kewalaka/Terraform-CICD-YAMLTemplates/_apis/build/status/Terraform-CICD-YAMLTemplates?branchName=main&stageName=Terraform%20Plan%20(auea%20-%20dev))](https://dev.azure.com/kewalaka/Terraform-CICD-YAMLTemplates/_build/latest?definitionId=5&branchName=main). Apply: [![Build Status](https://dev.azure.com/kewalaka/Terraform-CICD-YAMLTemplates/_apis/build/status/Terraform-CICD-YAMLTemplates?branchName=main&stageName=Terraform%20Apply%20(auea%20-%20dev))](https://dev.azure.com/kewalaka/Terraform-CICD-YAMLTemplates/_build/latest?definitionId=5&branchName=main)

# Introduction 

This is an opinionated template that illustrates how to build a devops pipeline for a Terraform project using Azure blob storage for remote state management.

The pipeline logic is split into stages, jobs and tasks for composability, via simple changes to [/pipelines/terraform.pipeline.yml](/pipelines/terraform.pipeline.yml) it is easy to add multiple environments and locations (samples included in comments!).

All secrets should be stored in KeyVault (or equivalent), the service principal credentials required to bootstrap Terraform are obtained via the AzureRM Service Connection during the pipeline run.  

This is a sample, there is more that can be done to make it better.  Pull requests are welcome!

## "I know what I'm doing, show me the money!"

* Create your new Azure DevOps project, and clone this one into it.
* In Azure DevOps, create an AzureRM service connection.
* Specify basic environment parameters in [/pipelines/variables/dev.job.vars.yml](/pipelines/variables/dev.job.vars.yml)
* In Azure DevOps, register a new pipeline pointing to [/pipelines/terraform.pipeline.yml](/pipelines/terraform.pipeline.yml) - the entry point for the pipeline.

Start adding Terraform code!

## Yowser!  Go slower

To go right back to the beginning, check out [Getting started](/docs/Getting-started.md)

TODO - make [add to an existing project](docs/Add-Pipelines-To-An-Existing-Project.md) better...

## Do you have a sample?

[Sure do](https://dev.azure.com/kewalaka/tfSample-KeyVaultRBAC)!  The sample uses this pipeline template and includes a small amount of Terraform code to deploy a KeyVault using Azure IAM to secure the access policy.

## Azure service principal setup

Check out [helpers/New.ServicePrincipal.ps1](./helpers/New-ServicePrincipal.ps1), this code will create a resource group (RG) for your deployment & the service principal scoped to this RG.

## Local development environment

See these [instructions](/docs/Setup-a-local-dev-environment.md) for how to set up a local development environment.

## Updating Terraform versions

The included [main.tf](main.tf) includes logic to pin to a specific version of Terraform and providers in use (AzureRM & AzureAD).

## Why did you do it like *that*?

There are a few [Design Notes](/docs/Design-Notes.md) in the Wiki with some background, it is WIP.