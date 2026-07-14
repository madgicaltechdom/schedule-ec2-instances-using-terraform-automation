variable "workspace_to_environment_map" {
  type = map(string)
  default = {
    qa  = "qa"
    prd = "prd"
  }
}

variable "cron_stop" {
  description = "Cron expression to stop fleet at 8 PM IST (14:30 UTC), Mon-SAT. Sunday stays stopped."
  default     = "30 14 ? * MON-SAT *"
}

variable "cron_start" {
  description = "Cron expression to start fleet at 9 AM IST (03:30 UTC), Mon-SAT. Sunday stays stopped."
  default     = "30 03 ? * MON-SAT *"
}

variable "fleet_ids" {
  description = "Comma-separated list of EC2 Fleet IDs to schedule"
  type        = list(string)
  default     = []
}

variable "enable" {
  default = true
}

locals {
  environment      = lookup(var.workspace_to_environment_map, terraform.workspace, "qa")
  identifier       = local.environment
  fleet_ids_string = join(",", var.fleet_ids)
}
