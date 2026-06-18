variable "environment_name" {
  type        = string
  description = "Name of the environment"
}

output "result" {
  value = {
    environment-name = var.environment_name
    created-by       = "retail-store-sample-app"
    devopsagent      = "true"
    auto-delete      = "no"
  }
  description = "Computed tag results"
}