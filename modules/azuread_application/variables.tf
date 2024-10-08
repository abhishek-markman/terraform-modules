variable "name" {
  description = "Name of the application."
}

variable "homepage" {
  description = "The URL to the application's home page. If no homepage is specified this defaults to `https://{name}`"
  default     = null
}

variable "key_vault_id" {
  description = "Id of the key vault to access secret"
  type        = string
  default     = null
}

variable "identifier_uris" {
  description = "A list of user-defined URI(s) that uniquely identify a Web application within it's Azure AD tenant, or within a verified custom domain if the application is multi-tenant."
  type        = list(string)
  default     = []
}

variable "redirect_uris" {
  description = "A list of URLs that user tokens are sent to for sign in, or the redirect URIs that OAuth 2.0 authorization codes and access tokens are sent to."
  type        = list(string)
  default     = []
}

variable "rotation_days" {
  description = "Azure secret validity"
  type        = number
  default     = 180
}

variable "access_token_issuance_enabled" {
  description = "Does this Azure AD Application allow OAuth2.0 implicit flow tokens?"
  type        = bool
  default     = false
}

variable "id_token_issuance_enabled" {
  description = "Whether this web application can request an ID token using OAuth 2.0 implicit flow."
  type        = bool
  default     = false
}

variable "type" {
  description = "Type of an application: `webapp/api` or `native`."
  default     = "webapp/api"
}

variable "required_resource_access" {
  description = "Required resource access for this application."
  type = list(
    object({
      resource_app_id = string
      resource_access = list(
        object({
          id   = string
          type = string
      }))
  }))
}

variable "group_membership_claims" {
  description = " Configures the groups claim issued in a user or OAuth 2.0 access token that the app expects. Possible values are None, SecurityGroup, DirectoryRole, ApplicationGroup or All."
  type        = list(string)
  default     = ["None"]
}

variable "sign_in_audience" {
  description = "The Microsoft account types that are supported for the current application. Must be one of AzureADMyOrg, AzureADMultipleOrgs, AzureADandPersonalMicrosoftAccount or PersonalMicrosoftAccount. Defaults to AzureADMyOrg."
  type        = string
  default     = "AzureADandPersonalMicrosoftAccount"
}

variable "end_date" {
  description = "The End Date which the Password is valid until, formatted as a RFC3339 date string (e.g. 2018-01-01T01:02:03Z)."
  default     = null
}

variable "assignments" {
  description = "List of role assignments this application should have access to."
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

variable "app_roles" {
  description = "List of app roles to associate to the application"
  type = list(object({
    allowed_member_types = list(string)
    description          = string
    display_name         = string
    value                = string
  }))
  default = []
}

variable "access_token" {
  description = "Manages optional claims for an application registration."
  type = list(object({
    additional_properties = optional(list(string), [])
    source                = optional(string, null)
    name                  = string
    essential             = optional(bool, false)
  }))
  default = []
}