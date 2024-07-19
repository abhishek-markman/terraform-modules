variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to be imported."
  nullable    = false
}

variable "location" {
  type        = string
  description = "The location of the vnet to create."
  nullable    = false
}

variable "address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "The address space that is used by the virtual network."
}

variable "bgp_community" {
  type        = string
  default     = null
  description = "(Optional) The BGP community attribute in format `<as-number>:<community-value>`."
}

variable "ddos_protection_plan" {
  type = object({
    enable = bool
    id     = string
  })
  default     = null
  description = "The set of DDoS protection plan configuration"
}

# If no values specified, this defaults to Azure DNS
variable "dns_servers" {
  type        = list(string)
  default     = []
  description = "The DNS servers to be used with vNet."
}

variable "nsg_ids" {
  type = map(string)
  default = {
  }
  description = "A map of subnet name to Network Security Group IDs"
}

variable "route_tables_ids" {
  type        = map(string)
  default     = {}
  description = "A map of subnet name to Route table ids"
}

variable "subnet_names" {
  type        = any
  default     = {}
  description = "A list of subnets inside the vNet."
}

variable "nsg_subnet_association" {
  type        = any
  default     = {}
  description = "NSG details to be associated to subnet"
}

variable "subnet_route_table_association" {
  type        = any
  default     = {}
  description = "Route table details to be associated to subnet"
}

variable "tags" {
  type = map(string)
  default = {
    DeployedFrom = "Terraform"
  }
  description = "The tags to associate with your network and subnets."
}

variable "vnet_name" {
  type        = string
  default     = "acctvnet"
  description = "Name of the vnet to create"
}