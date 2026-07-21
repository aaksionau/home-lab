terraform {
  required_version = ">= 1.7.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      # v0.9+ is a from-scratch, breaking rewrite with an entirely different
      # (attribute-based) schema. Pin to the 0.8.x line with the classic
      # block-based schema this config is written against — "~> 0.8" alone
      # would still float up to 0.9.x since it only has two version parts.
      version = "~> 0.8.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
