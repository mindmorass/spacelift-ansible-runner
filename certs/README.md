# Enterprise DPI Certificates

This directory contains the enterprise root CA certificates used for Deep Packet Inspection (DPI).

## Certificate Files

Place your enterprise CA certificate files here with the `.crt` extension:

```
certs/
├── README.md
└── enterprise-root-ca.crt    # Your enterprise root CA certificate
```

## Requirements

- Certificates must be in **PEM format** (Base64 encoded)
- Files must have the `.crt` extension
- Multiple certificate files are supported

## Adding New Certificates

1. Obtain the certificate in PEM format
2. Add the `.crt` file to this directory
3. Create a PR to trigger image rebuilds
4. After merge, all base images will include the new certificate

## Certificate Renewal

When enterprise certificates are renewed:

1. Replace the existing `.crt` file(s) with the new certificate(s)
2. Create a PR with the updated certificate
3. Bump the version tag (e.g., `v1.2.3` → `v1.3.0`)
4. Notify teams to update their base image references

## Verification

To verify certificates are installed in a running container:

```bash
# Check certificate is in trust store
cat /etc/ssl/certs/ca-certificates.crt | grep -A1 "BEGIN CERTIFICATE"

# Test HTTPS connection through DPI
curl -v https://internal-service.lakeview.com
```

## Security Notes

- These certificates are **public CA certificates**, not private keys
- They are safe to commit to the repository
- Do NOT add private keys or other secrets to this directory
