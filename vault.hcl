listener "tcp" {
    address = "127.0.0.1:8200"
    // tls_disable = 1
    tls_disable = 0
    tls_cert_file="certs/tls/vault-tls-certificate.pem"
    tls_key_file="certs/tls/vault-tls-private-key.pem"
}

storage "file" {
    path = "vault/data"
}

ui = true

// api_addr = "http://127.0.0.1:8200"
// cluster_addr = "http://127.0.0.1:8201"
api_addr = "https://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"