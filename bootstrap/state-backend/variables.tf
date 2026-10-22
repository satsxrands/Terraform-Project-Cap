variable "region" {
  type        = string
  description = "AWS region for the state buckets"
  default     = "af-south-1"
}

variable "prefix" {
  type        = string
  description = "Owner prefix used in bucket names, e.g. trimm-st"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.prefix))
    error_message = "prefix must be 3-20 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environments" {
  type        = list(string)
  description = "Environments that each get their own state bucket"
  default     = ["dev", "qa", "prd"]

  validation {
    condition     = alltrue([for e in var.environments : contains(["dev", "qa", "prd"], e)])
    error_message = "environments may only contain dev, qa and prd."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every bootstrap resource"
  default = {
    APP       = "capitec-terraform-training"
    OWNER     = "Geeks4Learning"
    DEVELOPER = "trimm-st"
  }
}
