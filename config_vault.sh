#!/bin/bash
clear

Menu() {
    echo -e '\n'
    echo "========================================================================="
    echo "[1] Gerar certificados para o Vault server usando o proprio Vault"
    echo "[2] Gerar certificados cliente para login no vault"
    echo "[3] Configurar a autenticacao por certificado "
    echo "[4] Testar Login no Vault (Certificar que o TLS esta habilitado no Vault)"
    echo "[5] Sair"
    echo "========================================================================="
    echo -e '\n'
    echo "Opcao: "
    read opcao
    case $opcao in 
    1) VaultCertGen ;;
    2) VaultClientCertGen ;;
    3) VaultCertAuth ;;
    4) VaultLogin ;;
    5) Sair ;;
    *) "Opcao invalida" ; echo; Menu ;;
    esac
}

VaultCertGen() {
mkdir -p certs/ca
mkdir certs/int
mkdir certs/tls
mkdir certs/client

#Configuração do Vault como root CA
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

echo "Gerando os certificados de root CA"

vault write -format=json pki/root/generate/internal \
common_name="vault-ca-root-pki" | tee \
>(jq -r .data.certificate > certs/ca/vault-ca-root-pki.pem) \
>(jq -r .data.issuing_ca > certs/ca/vault-ca-root-pki-issuing.pem) \
>(jq -r .data.private_key > certs/ca/vault-ca-root-pki-key.pem)

vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

#Configuração do Vault como Intermediario
#Após este passo, todos os certificados do Vault serão gerados a partir do intermediario

vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

#Gera o CSR para que o CA root assine
vault write -format=json pki_int/intermediate/generate/internal \
common_name="vault-ca-root-pki Intermediate Authority" | jq -r '.data.csr' > certs/int/vault-ca-root-pki-int.csr

#Vault CA assinando o certificado do intermediario
vault write -format=json pki/root/sign-intermediate csr=@certs/int/vault-ca-root-pki-int.csr \
common_name=”vault-ca-root-pki-int” \
format=pem_bundle ttl=43800h \
| jq -r '.data.certificate' > certs/int/vault-ca-root-pki-int.pem

#Seta o certificado assinado pelo root no path do intermediario
vault write pki_int/intermediate/set-signed certificate=@certs/int/vault-ca-root-pki-int.pem

vault write pki_int/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"


# Criação de Role PKI para certificados do vault server

vault write pki_int/roles/vault \
allow_any_name=true \
max_ttl=720h \
generate_lease=true

vault write -format=json pki_int/issue/vault \
common_name="vault-tls" ip_sans="127.0.0.1" | tee \
>(jq -r .data.certificate > certs/tls/vault-tls-certificate.pem) \
>(jq -r .data.issuing_ca > certs/tls/vault-tls-issuing-ca.pem) \
>(jq -r .data.private_key > certs/tls/vault-tls-private-key.pem)


Menu
}

VaultClientCertGen() {

# Criar nova role dentro do PKI para gerar certificados
# para login no vault
# Agora, temos duas roles dentro do pki_int, uma que gera
# certificados para o vault server e outra para login 
# Sao elas respectivamente vault e vault-cert

vault write pki_int/roles/vault-cert \
allow_any_name=true \
max_ttl=720h \
generate_lease=true

# Gerar certificado para se autenticar no vault

vault write -format=json pki_int/issue/vault-cert \
common_name=”login-cert” | tee \
>(jq -r .data.certificate > certs/client/user1-cert-certificate.pem) \
>(jq -r .data.issuing_ca > certs/client/user1-cert-issuing-ca.pem) \
>(jq -r .data.private_key > certs/client/user1-cert-private-key.pem)

echo "Certificados Criados e salvos no diretorio cert/client"

Menu
}

VaultCertAuth() {

#Criação e armazenamento de segredo para testes

# vault secrets enable -path=secret kv-v2

# vault kv put secret/mydemo/cert username="mydemocreds" password="123abc"

# vault policy write user1 - <<EOF
# path "secret/data/mydemo/cert" {
#    capabilities=["read"]
# }
# EOF

vault auth enable cert

#Criar a role de certificado para o user1

vault write auth/cert/certs/user1 \
display_name=user1 \
policies=user1 \
# token_bound_cidrs="127.0.0.1" \
certificate=@certs/client/user1-cert-certificate.pem

Menu
}


VaultLogin() {
    
echo "Login com o certificado via CLI"
echo '\n'
vault login -method=cert \
-ca-cert=certs/client/user1-cert-issuing-ca.pem \
-client-cert=certs/client/user1-cert-certificate.pem \
-client-key=certs/client/user1-cert-private-key.pem \
name=user1

Menu
}

Sair() {
    clear
    exit
}
clear
Menu