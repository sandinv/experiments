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
    "etcd-${idx}=http://etcd-${idx}:2380"
  ])
}

resource "docker_image" "etcd" {
  name = "bitnami/etcd:3.5.9"
}

resource "docker_container" "etcd" {
  name  = "etcd-${count.index}"
  count = var.etcd_members
  image = docker_image.etcd.image_id

  env = [
    "ETCD_LISTEN_CLIENT_URLS=http://172.0.0.1${count.index}:2379",
    "ETCD_LISTEN_PEER_URLS=http://172.0.0.1${count.index}:2380",
    "ETCD_INTIAL_CLUSTER_TOKEN=${var.token}",
    "ETCD_NAME=etcd-${count.index}",
    "ETCD_DATA_DIR=data.etcd",
    "ETCD_INITIAL_ADVERTISE_PEER_URLS=http://172.0.0.1${count.index}:2380",
    "ETCD_ADVERTISE_CLIENT_URLS=http://172.0.0.1${count.index}:2379",
    "ETCD_INITIAL_CLUSTER=${local.cluster}",
    "ETCD_INITIAL_CLUSTER_STATE=new",
  ]

  command = [
    "etcd"
  ]

  networks_advanced {
    name         = docker_network.etcd.id
    ipv4_address = "172.0.0.1${count.index}"
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
