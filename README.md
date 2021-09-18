# Use Case: Criação e autenticação de certificados X509 no Vault


Caso encontre o erro abaixo, garanta que o certificado criado para o Vault é confiado pela sua máquina.

```bash
Error unsealing: Put "https://127.0.0.1:8200/v1/sys/unseal": x509: certificate signed by unknown authority
```

Não esqueça que a autenticação via certificados funciona somente com o Vault rodando em HTTPS