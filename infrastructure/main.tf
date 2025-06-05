terraform {
  required_providers {
    pulsar = {
      source = "datastax/pulsar"
      version = ">=1.0.0"
    }
  }
}

provider "pulsar" {
  web_service_url = "http://localhost:8080"
  pulsar_token    = ""
}

resource "pulsar_tenant" "finrisk" {
  tenant = "finrisk"
  admin_roles = ["admin"]
  allowed_clusters = ["standalone"]
}
