locals {

  default_suffix       = "${var.appname}-${var.env_code}-${var.short_location_code}"
  default_short_suffix = "${var.short_appname}${var.env_code}${var.short_location_code}"

  # add resource names here, using CAF-aligned naming conventions
  resource_group_name = "rg-${local.default_suffix}"

  location = data.azurerm_resource_group.parent.location

  default_tags = merge(
    var.default_tags,
    tomap({
      "Environment" = var.env_code
    })
  )
}
