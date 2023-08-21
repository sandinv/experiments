locals {
  certs_path = "/etc/ssl/certs"
}

resource "docker_image" "etcd-client" {
  name = "etcd-client"

  build {
    context = "."
    tag     = ["etcd-client:develop"]
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "go-etcd/*") : filesha1(f)]))
  }
}

resource "docker_container" "etcd-client" {
  name    = "etcd-client"
  image   = docker_image.etcd-client.image_id
  restart = "always"

  volumes {
    container_path = local.certs_path
    host_path      = abspath("${path.module}/certs")
  }
  networks_advanced {
    name = docker_network.etcd.id
  }

  env = [
    "ETCD_ENDPOINTS=${local.endpoints}",
    "CLIENT_CERT=${local.certs_path}/client.pem",
    "CLIENT_KEY=${local.certs_path}/client.key",
    "CLIENT_CA=${local.certs_path}/ca.pem",
  ]
}
