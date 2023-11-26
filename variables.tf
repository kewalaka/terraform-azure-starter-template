variable "appname" {
  description = "Longer name of the application used for naming conventions."
  type        = string
}

variable "short_appname" {
  description = "Short name of the application used for naming conventions."
  type        = string
  validation {
    # this is assuming that an environment name will be 4 characters or less - example for a storage account - st12345678901234prodae01
    condition     = length(var.short_appname) <= 14
    error_message = "Err: The short_appname should be 14 characters or less to fit within naming conventions for resources such as storage accounts."
  }
}

variable "short_location_code" {
  description = "A short form of the location where resource are deployed, used in naming conventions."
  type        = string
  default     = "auea"
}

variable "env_code" {
  description = "Short name of the environment used for naming conventions (e.g. dev, test, prod)."
  type        = string
  validation {
    condition = contains(
      ["dev", "test", "uat", "prod"],
      var.env_code
    )
    error_message = "Err: environment should be one of dev, test or prod."
  }
  validation {
    condition     = length(var.env_code) <= 4
    error_message = "Err: environment code should be 4 characters or shorter."
  }
}

variable "environment_tags" {
  description = "Tags that are environment specific"
  type        = map(string)
}
