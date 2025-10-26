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
      ["dev", "tst", "test", "uat", "prod"],
      var.env_code
    )
    error_message = "Err: environment should be one of dev, tst, test, uat or prod."
  }
  validation {
    condition     = length(var.env_code) <= 4
    error_message = "Err: environment code should be 4 characters or shorter."
  }
}

# tags are expected to be provided
variable "default_tags" {
  description = <<DESCRIPTION
Tags to be applied to resources.  Default tags are expected to be provided in local.default_tags, 
which is merged with environment specific ones in ``environments\env.terraform.tfvars``.
Most resources will simply apply the default tags like this:

```terraform
tags = local.default_tags
```

Additional tags can be provided by using a merge, for instance:

```terraform
tags = merge(
    local.default_tags,
    tomap({
      "MyExtraResourceTag" = "TheTagValue"
    })
)
```

Note you can also use the above mechanims to override or modify the default tags for an individual resource,
since only unique items in a map are retained, and later tags supplied to merge() function take precedence.
DESCRIPTION
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Existing Azure Resource Group name to deploy into. If null, defaults to rg-<appname>-<env_code>."
  type        = string
  default     = null
  validation {
    condition     = var.resource_group_name == null || can(regex("^[A-Za-z0-9._()\\-]+$", var.resource_group_name))
    error_message = "Resource group name may only contain alphanumeric characters, dash (-), underscore (_), parentheses, and periods."
  }
}
