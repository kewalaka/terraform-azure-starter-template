locals {
  # TODO: set an app name that fits your naming conventions if needed
  # Keep this value simple and compliant with Azure naming rules
  appname        = "startertemplate"
  default_suffix = "${local.appname}-${var.env_code}"

  # optional computed short name
  # this assume two letters for the resource type, three for the location, and three for the environment code (= 24 chars max)
  # short_appname        = substr(replace(local.appname, "-", ""), 0, 16) 
  # default_short_suffix = "${local.short_appname}${var.env_code}"

  # add resource names here, using CAF-aligned naming conventions
  # allow override via variable; otherwise default to CAF-like pattern
  resource_group_name = coalesce(var.resource_group_name, "rg-${local.default_suffix}")

  # tflint-ignore: terraform_unused_declarations
  location = data.azurerm_resource_group.parent.location

  # tflint-ignore: terraform_unused_declarations
  default_tags = merge(
    var.default_tags,
    tomap({
      "Environment"  = var.env_code
      "LocationCode" = var.short_location_code
    })
  )
}
