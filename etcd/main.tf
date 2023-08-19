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

# https://amod-kadam.medium.com/create-private-ca-and-certificates-using-terraform-4b0be8d1e86d

resource "tls_private_key" "etcd-ca-key" {
  algorithm = "RSA"
}

resource "local_file" "etcd-ca-key" {
  content         = tls_private_key.etcd-ca-key.private_key_pem
  filename        = "${path.module}/certs/ca.key"
  file_permission = "0600"
}

resource "tls_self_signed_cert" "etcd-ca-cert" {
  private_key_pem = tls_private_key.etcd-ca-key.private_key_pem

  is_ca_certificate = true

  validity_period_hours = 43800 # 1825 days or 5 years

  subject {
    country      = "SP"
    province     = "Madrid"
    locality     = "Madrid"
    common_name  = "etcd"
    organization = "etcd experiments"
  }

  allowed_uses = [
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

resource "local_file" "etcd-ca-cert" {
  content         = tls_self_signed_cert.etcd-ca-cert.cert_pem
  filename        = "${path.module}/certs/ca.pem"
  file_permission = "0600"
}


resource "tls_private_key" "etcd-member-key" {
  count     = var.etcd_members
  algorithm = "RSA"
}

resource "local_file" "etcd-cert" {
  count           = var.etcd_members
  content         = tls_private_key.etcd-member-key[count.index].private_key_pem
  filename        = "${path.module}/certs/etcd-${count.index}.key"
  file_permission = "0600"
}

resource "tls_cert_request" "etcd-csr" {
  count = var.etcd_members

  private_key_pem = tls_private_key.etcd-member-key[count.index].private_key_pem

  dns_names = ["etcd-${count.index}"]

  subject {
    common_name  = "etcd-${count.index}"
    organization = "etcd"
  }
}

resource "tls_locally_signed_cert" "etcd-cert" {
  count              = var.etcd_members
  cert_request_pem   = tls_cert_request.etcd-csr[count.index].cert_request_pem
  ca_private_key_pem = tls_private_key.etcd-ca-key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.etcd-ca-cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "etcd-member-cert" {
  count           = var.etcd_members
  content         = tls_locally_signed_cert.etcd-cert[count.index].cert_pem
  file_permission = "0600"
  filename        = "${path.module}/certs/etcd-${count.index}.cert"
}


resource "tls_private_key" "client-key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "client-csr" {
  private_key_pem = tls_private_key.client-key.private_key_pem

  subject {
    common_name  = "client"
    organization = "etcd"
  }
}
resource "tls_locally_signed_cert" "client-cert" {
  cert_request_pem   = tls_cert_request.client-csr.cert_request_pem
  ca_private_key_pem = tls_private_key.etcd-ca-key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.etcd-ca-cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}
resource "local_file" "client-key" {
  content         = tls_private_key.client-key.private_key_pem
  filename        = "${path.module}/certs/client.key"
  file_permission = "0600"
}


resource "local_file" "client-cert" {
  content         = tls_locally_signed_cert.client-cert.cert_pem
  filename        = "${path.module}/certs/client.pem"
  file_permission = "0600"
}


