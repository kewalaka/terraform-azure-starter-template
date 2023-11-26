locals {

  resource_group_name = "rg-${var.appname}-${var.env_code}-${var.short_location_code}"

  location = data.azurerm_resource_group.parent.location

  default_tags = merge(
    var.environment_tags,
    tomap({
      "CreatedBy" = data.azuread_service_principal.logged_in_app.display_name
    })
  )
}
