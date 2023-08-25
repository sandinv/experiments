variable "zookeeper_members" {
  description = "zookeeper member count"
  type        = string
  default     = 3
}

locals {
  zk_servers = join(" ", [
    for idx in range(1, var.zookeeper_members + 1) :
    "server.${idx}=zoo${idx}:2888:3888;2181"
  ])

}


resource "docker_image" "zookeeper" {
  name = "zookeeper:3.9"

}

resource "docker_container" "zookeeper_cluster" {
  count = var.zookeeper_members
  image = docker_image.zookeeper.image_id

  name = "zoo${count.index + 1}"

  restart = "always"

  env = [
    "ZOO_MY_ID=${count.index + 1}",
    "ZOO_SERVERS=${local.zk_servers}"
  ]

  networks_advanced {
    name         = docker_network.zookeeper.id
    ipv4_address = "172.0.0.1${count.index}"
  }


  volumes {
    container_path = "/data"
    volume_name    = docker_volume.zookeeper_data[count.index].name
  }

  volumes {
    container_path = "/datalog"
    volume_name    = docker_volume.zookeeper_datalog[count.index].name
  }
}

resource "docker_volume" "zookeeper_data" {
  count = var.zookeeper_members
  name  = "zoo-${count.index + 1}"
}

resource "docker_volume" "zookeeper_datalog" {
  count = var.zookeeper_members
  name  = "zoo-log-${count.index + 1}"
}



resource "docker_network" "zookeeper" {
  name   = "zookeeper"
  driver = "bridge"

  ipam_config {
    subnet  = "172.0.0.0/16"
    gateway = "172.0.0.1"
  }
}
