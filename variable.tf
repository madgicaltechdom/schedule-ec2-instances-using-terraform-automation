variable "workspace_to_environment_map" {
  type = map(string)
  default = {
    qa  = "qa"
    prd = "prd"
  }
}

variable "cron_stop" {
  description = "Cron expression to define when to trigger a stop of the DB"
  default     = "30 14 ? * MON-SAT *"
}

variable "cron_start" {
  description = "Cron expression to define when to trigger a start of the DB"
  default     = "30 03 ? * MON-SAT *"
}

variable "enable" {
  default = true
}

locals {
  environment      = lookup(var.workspace_to_environment_map, terraform.workspace, "qa")
  identifier       = local.environment
}
