variable "key_vault_name" {
  description = "Name of the Key Vault to be created"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type        = string
  description = "The location of Key vault resouce"
}

variable "subnet_id" {
  type    = string
  default = null
}

variable "network_acls" {
  type    = map(any)
  default = {}
}

variable "kv_access_policy" {
  default = {}
  type    = map(any)
}

variable "sku_name" {
  type    = string
  default = "standard"
}

variable "enabled_for_deployment" {
  type    = bool
  default = true
}

variable "enabled_for_disk_encryption" {
  type    = bool
  default = true
}

variable "enabled_for_template_deployment" {
  type    = bool
  default = true
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "private_connection_resource_alias" {
  type    = string
  default = null
}

variable "private_dns_zone_group" {
  type    = map(any)
  default = {}
}

variable "ip_configuration" {
  type    = map(any)
  default = {}
}

variable "kv_key" {
  type    = map(any)
  default = {}
  # key_type - Specifies the Key Type to use for this Key Vault Key. Possible values are EC (Elliptic Curve), EC-HSM, RSA and RSA-HSM.
  # key_size - Specifies the Size of the RSA key to create in bytes. For example, 1024 or 2048. Note: This field is required if key_type is RSA or RSA-HSM.
  # curve - Specifies the curve to use when creating an EC key. Possible values are P-256, P-256K, P-384, and P-521.
  # key_opts - Possible values include: [decrypt, encrypt, sign, unwrapKey, verify and wrapKey].
}

variable "enable_rbac_authorization" {
  type    = bool
  default = true
}

variable "purge_protection_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(any)
  default = {}
}