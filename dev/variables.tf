variable "location" {
  type        = string
  description = "The location of the Resource group to create."
  default     = "eastus"
}

variable "environment" {
  type        = string
  description = "The Environment name."
  default     = "dev"
}

variable "unique_name" {
  type        = string
  description = "The name of project/customer or something unique."
  default     = "laurelag"
}