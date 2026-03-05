# RAGFlow Local Setup Guide

This guide walks you through running RAGFlow locally for evaluation and development. You can choose either **Docker (all-in-one)** for quick testing or **from source** for development.

---

## Prerequisites

- **Docker** >= 24.0.0 & **Docker Compose** >= v2.26.1
- **Python** 3.10–3.12 (for from-source only)
- **Node.js** >= 18.20.4 (for from-source only)
- **uv** (Python package manager): `pipx install uv pre-commit`
- **RAM** >= 16 GB, **Disk** >= 50 GB

### macOS-Specific

- `vm.max_map_count` does not apply on macOS (it's Linux-only).
- Uncomment `MACOS=1` in `docker/.env` for performance optimizations.
- Install jemalloc: `brew install jemalloc`

---

## Option 1: Docker (Recommended for Quick Testing)

Simplest way to run everything in containers.

### 1. Configure environment

Edit `docker/.env` (no `.env.local` needed). Defaults usually work for local testing. Useful settings:

```bash
# Optional: Use macOS optimizations
MACOS=1

# Optional: If you can't access HuggingFace directly
# HF_ENDPOINT=https://hf-mirror.com
```

### 2. Start RAGFlow

```bash
cd docker
docker compose -f docker-compose.yml up -d
```

### 3. Verify startup

```bash
docker logs -f docker-ragflow-cpu-1
```

Look for the RAGFlow ASCII banner and "Running on all addresses (0.0.0.0)".

### 4. Access the app

Open **http://localhost** (port 80) in your browser.

### 5. Configure LLM/Embedding (required for chat)

After first login, go to **Settings → API** and add:
- **Chat model**: e.g., OpenAI, DeepSeek, or another supported provider and its API key.
- **Embedding model**: API key for an embedding provider, or use the optional local TEI service.

See [LLM API Key Setup](https://ragflow.io/docs/dev/llm_api_key_setup) for details.

---

## Option 2: From Source (Development)

Run backend and frontend locally with dependencies in Docker.

### 1. Install Python dependencies

```bash
cd /Users/ttompkins/src/GenAI/AI-Chat-Apps/ragflow
uv sync --python 3.12 --all-extras
uv run download_deps.py
pre-commit install
```

### 2. Environment variables

The project uses **`docker/.env`** (not `.env.local`). The backend loads it via `docker/launch_backend_service.sh`. Defaults are fine for local dev. Optional overrides:

| Variable   | Purpose                                      |
|-----------|-----------------------------------------------|
| `MACOS=1` | Enable macOS optimizations                    |
| `HF_ENDPOINT` | HuggingFace mirror if access is limited   |
| `DOC_ENGINE` | `elasticsearch` (default) or `infinity`  |

### 3. Start dependency services

```bash
docker compose -f docker/docker-compose-base.yml up -d
```

This starts MySQL, Elasticsearch, MinIO, Redis (and optionally Infinity, etc., depending on profiles).

### 4. Add `/etc/hosts` (optional)

If you use hostnames like `es01`, `mysql`, `minio`, `redis` in config, add:

```
127.0.0.1       es01 infinity mysql minio redis sandbox-executor-manager
```

The checked-in `conf/service_conf.yaml` already uses `localhost` with the right ports, so this step is often unnecessary.

### 5. Service configuration

`conf/service_conf.yaml` is pre-configured for local development:

- MySQL: `localhost:5455`
- MinIO: `localhost:9000`
- Elasticsearch: `localhost:1200`
- Redis: `localhost:6379`

Override with `conf/local.service_conf.yaml` if needed; it is merged on top of the main config.

### 6. Start backend

```bash
source .venv/bin/activate
export PYTHONPATH=$(pwd)
bash docker/launch_backend_service.sh
```

Keep this terminal open. The backend will run on ports 9380 (API) and 9381 (admin).

### 7. Start frontend (new terminal)

```bash
cd web
npm install
npm run dev
```

Frontend defaults to **http://localhost:9222** and proxies API requests to the backend.

### 8. Access the app

Open **http://localhost:9222** in your browser.

### 9. Stop services

```bash
# Stop backend
pkill -f "ragflow_server.py|task_executor.py"

# Stop dependency containers
docker compose -f docker/docker-compose-base.yml down
```

---

## Configuration Summary

| File                          | Purpose                                                        |
|-------------------------------|----------------------------------------------------------------|
| `docker/.env`                 | Main environment config (Docker and backend)                   |
| `conf/service_conf.yaml`      | Backend services: DB, ES, MinIO, Redis, LLM config             |
| `conf/local.service_conf.yaml`| Local overrides (optional)                                     |
| `web/.env`                    | Frontend dev config (e.g. `PORT=9222`)                         |
| `web/.env.development`        | Vite base URL for development                                  |

---

## Minimal LLM Configuration

For a usable chatbot, you need:

1. **Chat model**: e.g., OpenAI `gpt-4`, DeepSeek, etc.
2. **Embedding model**: for RAG retrieval (e.g., OpenAI embeddings or local TEI).

Configure via:

- **UI**: Settings → API after login, or
- **YAML**: `conf/service_conf.yaml` or `conf/local.service_conf.yaml` under `user_default_llm`.

---

## Troubleshooting

| Issue                     | Possible cause / fix                                          |
|---------------------------|----------------------------------------------------------------|
| `network abnormal`        | Wait for backend/frontend to fully start; retry after ~1 min  |
| Elasticsearch connection  | Ensure `vm.max_map_count >= 262144` on Linux                   |
| Port already in use       | Change `SVR_HTTP_PORT` in `docker/.env` or ports in config     |
| HuggingFace download      | Set `HF_ENDPOINT=https://hf-mirror.com` if you’re in China     |
| jemalloc not found        | `brew install jemalloc` on macOS                              |

---

## AWS Deployment Feasibility

RAGFlow does **not** provide AWS-specific deployment automation (Terraform, CloudFormation, EKS-specific values), but it **does** support the key building blocks needed for an AWS deployment.

### What RAGFlow Already Supports

| Component | AWS Equivalent | Support |
|-----------|----------------|---------|
| **Object storage** | Amazon S3 | ✅ Native. Set `STORAGE_IMPL=AWS_S3` and configure `s3` in `service_conf.yaml`. Supports IAM roles (no access key when using EC2/EKS instance roles). |
| **Vector/search** | Amazon OpenSearch | ✅ `DOC_ENGINE=opensearch`. Point `os.hosts` to your OpenSearch endpoint. |
| **Database** | Amazon RDS (MySQL) | ✅ Use external MySQL. Helm and Docker both support `MYSQL_HOST` etc. |
| **Cache/queue** | Amazon ElastiCache (Redis) | ✅ Use external Redis. Helm and Docker both support `REDIS_HOST` etc. |
| **Orchestration** | Amazon EKS | ✅ Helm chart deploys to any Kubernetes cluster. Externalize MySQL, MinIO/Redis/OpenSearch per [helm/README.md](helm/README.md). |

### Relevant Configurations

**S3 (object storage):** In `service_conf.yaml` or `conf/local.service_conf.yaml`:

```yaml
# Enable S3 instead of MinIO
# Plus set env: STORAGE_IMPL=AWS_S3

s3:
  access_key: "your-access-key"   # or omit for IAM role
  secret_key: "your-secret-key"   # or omit for IAM role
  endpoint_url: "https://s3.amazonaws.com"
  bucket: "my-ragflow-bucket"
  region: "us-east-1"
  prefix_path: "ragflow"  # optional, for single-bucket mode
```

See [docs/administrator/migrate_to_single_bucket_mode.md](docs/administrator/migrate_to_single_bucket_mode.md) for S3 and IAM examples.

**Helm with external AWS services:** Example override:

```yaml
# values.override.yaml for EKS
mysql:
  enabled: false
minio:
  enabled: false
redis:
  enabled: false

env:
  STORAGE_IMPL: AWS_S3
  DOC_ENGINE: opensearch
  MYSQL_HOST: your-rds-endpoint.region.rds.amazonaws.com
  MYSQL_PORT: "3306"
  MYSQL_PASSWORD: "<from-secrets-manager>"
  REDIS_HOST: your-elasticache.xxx.cache.amazonaws.com
  REDIS_PORT: "6379"
  OPENSEARCH_PASSWORD: "<your-password>"
  # os.hosts in service_conf points to OpenSearch endpoint
```

### Deployment Approaches

1. **EKS + Helm (recommended)**  
   Deploy the Helm chart to EKS. Use RDS, ElastiCache, OpenSearch Service, and S3 as external services. Create infra (VPC, security groups, IAM, etc.) with Terraform/CDK/CloudFormation.

2. **EC2 + Docker Compose**  
   Run Docker Compose on EC2 and point it at RDS, ElastiCache, OpenSearch, and S3. Simpler operationally but less scalable.

3. **ECS**  
   Possible but not documented. Would require adapting the Helm/Docker config into ECS task definitions and services.

### Difficulty Assessment

| Factor | Assessment |
|--------|------------|
| **Component swap** | Easy. All dependencies can be externalized via config. |
| **S3 integration** | Easy. Native support, IAM compatible. |
| **OpenSearch** | Moderate. Amazon OpenSearch Service is API-compatible; verify index mappings and auth (IAM fine-grained, basic auth, etc.). |
| **Infrastructure** | You provide it. No Terraform/CloudFormation in the repo. |
| **Networking** | Standard. VPC, security groups, ALB/NLB, SSL. |
| **Estimated effort** | **1–2 weeks** for a DevOps/infra engineer to stand up a production-ready deployment (EKS + managed services). |

**Summary:** RAGFlow is well-suited for AWS. The main work is writing and maintaining infra-as-code for EKS, RDS, ElastiCache, OpenSearch, and S3, then wiring RAGFlow to those services via configuration.

---

## Next Steps

After RAGFlow is running:

1. Create a **Knowledge Base** and upload documents.
2. Set up a **Chat** application using that knowledge base.
3. Configure **Agents** and **MCP** if needed for advanced flows.

See the [RAGFlow documentation](https://ragflow.io/docs/dev/) for full guides.
