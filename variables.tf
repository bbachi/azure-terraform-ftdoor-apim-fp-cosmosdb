variable "location" {
  description = "The Azure Region in which all resources groups should be created."
}

variable "rg-name" {
  description = "The name of the resource group"
}

variable "cosmosdb_name" {
  description = "The name of the cosmos db"
}

variable "fn_storage_account_name" {
  description = "The name of the storage account name"
}

variable "fn_app_service_plan_name" {
  description = "The name of the function app service plan"
}

variable "function_app_name" {
  description = "The name of the function app"
}

variable "apim_name" {
  description = "name of the APIM"
}

variable "environment" {
  description = "The environment of the app"
}