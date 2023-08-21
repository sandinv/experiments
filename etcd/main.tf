# https://hub.docker.com/r/bitnami/etcd/
# https://github.com/bitnami/containers/tree/main/bitnami/etcd#readme

variable "etcd_members" {
  description = "etcd member count"
  type        = string
  default     = 3
}

variable "token" {
  description = "token for bootstrapping etcd"
  type        = string
  default     = "abc0123456"
}

locals {
  cluster = join(",", [
    for idx in range(var.etcd_members) :
    "etcd-${idx}=https://etcd-${idx}:2380"
  ])
  endpoints = join(",", [
    for idx in range(var.etcd_members) :
    "https://etcd-${idx}:2379"
  ])
}

resource "docker_image" "etcd" {
  name = "quay.io/coreos/etcd:v3.5.9"
}

resource "docker_container" "etcd" {
  name    = "etcd-${count.index}"
  count   = var.etcd_members
  image   = docker_image.etcd.image_id
  restart = "always"
  command = [
    "etcd",
    "-listen-client-urls", "https://172.0.0.1${count.index}:2379",
    "-listen-peer-urls", "https://172.0.0.1${count.index}:2380",
    "-initial-cluster-token", var.token,
    "-name", "etcd-${count.index}",
    "-initial-advertise-peer-urls", "https://172.0.0.1${count.index}:2380",
    "-advertise-client-urls", "https://172.0.0.1${count.index}:2379",
    "-initial-cluster-state", "new",
    "-initial-cluster", local.cluster,
    "-cert-file=/etc/ssl/certs/etcd-${count.index}.cert",
    "-key-file=/etc/ssl/certs/etcd-${count.index}.key",
    "-client-cert-auth",
    "-trusted-ca-file=/etc/ssl/certs/ca.pem",
    "-peer-cert-file=/etc/ssl/certs/etcd-${count.index}.cert",
    "-peer-key-file=/etc/ssl/certs/etcd-${count.index}.key",
    "-peer-client-cert-auth",
    "-peer-trusted-ca-file=/etc/ssl/certs/ca.pem",
  ]

  volumes {
    container_path = "/etc/ssl/certs"
    host_path      = abspath("${path.module}/certs")
  }

  networks_advanced {
    name         = docker_network.etcd.id
    ipv4_address = "172.0.0.1${count.index}"
  }

  ports {
    internal = 2379
    external = "2379${count.index}"
  }
}

resource "docker_network" "etcd" {
  name   = "etcd"
  driver = "bridge"

  ipam_config {
    subnet  = "172.0.0.0/16"
    gateway = "172.0.0.1"
  }
}
