# AWS Service Config Patch

For AWS deployment with OpenSearch and S3, apply these changes to `docker/service_conf.yaml.template`.

## 1. OpenSearch hosts (OS_HOSTS for AWS)

**Replace** the `os.hosts` line:

```yaml
  hosts: 'http://${OS_HOST:-opensearch01}:9201'
```

**With:**

```yaml
  hosts: '${OS_HOSTS:-http://${OS_HOST:-opensearch01}:9201}'
```

This lets you set `OS_HOSTS` to the full AWS OpenSearch endpoint URL (e.g. `https://search-xxx.us-east-1.es.amazonaws.com`).

## 2. S3 block (for STORAGE_IMPL=AWS_S3)

**Uncomment and update** the `s3` block (around line 72):

```yaml
s3:
  access_key: '${AWS_ACCESS_KEY_ID:-}'
  secret_key: '${AWS_SECRET_ACCESS_KEY:-}'
  region_name: '${AWS_REGION:-us-east-1}'
  endpoint_url: ''
  bucket: '${S3_BUCKET}'
  prefix_path: '${S3_PREFIX_PATH:-}'
  signature_version: 'v4'
```

When using an ECS task IAM role, leave `access_key` and `secret_key` empty (the defaults above). The boto3 client will use the task role automatically.
