resource "azurerm_resource_group" "resource_group" {
  name  = var.rg-name
  location = var.location
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_cosmosdb_account" "db" {
  name                = var.cosmosdb_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_automatic_failover = true
  mongo_server_version= "4.0"

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level  = "Eventual"
  }

  geo_location {
    location          = azurerm_resource_group.resource_group.location
    failover_priority = 0
  }
}

#Create Resource Group
resource "azurerm_storage_account" "fn_storage_account" {
  name                     = var.fn_storage_account_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "fn_app_service_plan" {
  name                = var.fn_app_service_plan_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "fn_app" {
  name                       = var.function_app_name
  location                   = azurerm_resource_group.resource_group.location
  resource_group_name        = azurerm_resource_group.resource_group.name
  app_service_plan_id        = azurerm_app_service_plan.fn_app_service_plan.id
  storage_account_name       = azurerm_storage_account.fn_storage_account.name
  storage_account_access_key = azurerm_storage_account.fn_storage_account.primary_access_key

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~3"
    FUNCTIONS_WORKER_RUNTIME = "node"
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING    = "${azurerm_storage_account.fn_storage_account.primary_connection_string}"
    WEBSITE_CONTENTSHARE                        = "${azurerm_storage_account.fn_storage_account.name}"
    COSMOSDB_CONNECTION_STR = azurerm_cosmosdb_account.db.connection_strings[0]
  }

  depends_on = [azurerm_cosmosdb_account.db]
}

resource "azurerm_api_management" "demo-apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  publisher_name      = "publisher"
  publisher_email     = "publisher.email@gmail.com"

  sku_name = "Developer_1"
}

resource "azurerm_frontdoor" "backend-demo-frontdoor" {
  name                                         = "backend-demo-${var.environment}"
  resource_group_name                          = var.rg-name
  enforce_backend_pools_certificate_name_check = false

  routing_rule {
    name               = "apim-rule-${var.environment}"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["backend-demo-frontdoor-${var.environment}"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "backend-apim-pool-${var.environment}"
    }
  }

  backend_pool_load_balancing {
    name = "exampleLoadBalancingSettings1"
  }

  backend_pool_health_probe {
    name = "exampleHealthProbeSetting1"
  }

  backend_pool {
    name = "backend-apim-pool-${var.environment}"
    backend {
      host_header = split("://", azurerm_api_management.demo-apim.gateway_url)[1]
      address     = split("://", azurerm_api_management.demo-apim.gateway_url)[1]
      http_port   = 80
      https_port  = 443
      weight = 100
    }

    load_balancing_name = "exampleLoadBalancingSettings1"
    health_probe_name   = "exampleHealthProbeSetting1"
  }

  frontend_endpoint {
    name      = "backend-demo-frontdoor-${var.environment}"
    host_name = "backend-demo-${var.environment}.azurefd.net"
    session_affinity_enabled = false
    session_affinity_ttl_seconds = 0
  }

  depends_on = [azurerm_api_management.demo-apim]
}