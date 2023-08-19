terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}
