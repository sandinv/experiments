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


