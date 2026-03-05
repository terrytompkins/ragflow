# Custom CA Certificate for Corporate Proxies

When behind a corporate proxy (e.g., Zscaler) that inspects HTTPS traffic, the proxy presents certs signed by your company CA. Docker containers don't have these certs by default, so outbound calls (e.g., to OpenAI) can fail with SSL errors.

## Setup

1. **Get your company CA cert**  
   Export the Zscaler/company root CA from your Mac Keychain or use the .pem file your IT provides.

2. **CA_BUNDLE_HOST_PATH must point to a FILE, not a directory**

   **Option A:** Copy the cert file to `docker/certs/company-ca-bundle.pem`  
   **Option B:** Set `CA_BUNDLE_HOST_PATH` in `.env` to the **full path of the .pem file**:
   ```
   CA_BUNDLE_HOST_PATH=/Users/you/path/to/your-cert.pem
   ```
   Use the path to the actual certificate file (e.g. `company-zscaler.pem`), not the folder containing it.

3. **Start with the certs override**
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.certs.yml up -d
   ```
