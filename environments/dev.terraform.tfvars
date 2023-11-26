# Settings that are specific to the dev environment
#
###  Please do NOT put sensitive values in here.
#
# Sensitive values should be added to Keyvault and sourced from there.
#
appname       = "sample1"
short_appname = "sample1"
env_code      = "dev"

# don't forget to check solution tags under global.terraform.tfvars
environment_tags = {
  "ApplicationName" = "My Sample App"
  "ApplicationRole" = "Demo"
  "Environment"     = "dev"
  "Owner"           = "Stu"
}
