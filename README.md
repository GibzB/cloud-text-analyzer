# Cloud Text Analyzer

A simple text analysis API built with Flask and deployed on Google Cloud Platform.

## What it does

- Analyzes text input (word count, character count)
- Runs on Cloud Run for scalability
- Uses Terraform for infrastructure management
- Automated deployment with GitHub Actions

## Architecture

```
┌─────────────┐     ┌─────────────┐    ┌──────────────┐
│   GitHub    │──▶  │ GitHub      ───▶│ Artifact     │
│ Repository  │     │ Actions     │    │ Registry     │
└─────────────┘     └─────────────┘    └──────────────┘
                           │                     │
                           ▼                     │
                  ┌──────────────┐               │
                  │  Terraform   │               │
                  │ (Deploy IaC) │               │
                  └──────────────┘               │
                           │                     │
                           ▼                     ▼
                  ┌─────────────────────────────────┐
                  │         Cloud Run               │
                  │  ┌─────────────────────────┐    │
                  │  │   Flask Application     │    │
                  │  │  (Internal Access Only) │    │
                  │  └─────────────────────────┘    │
                  └─────────────────────────────────┘
```

## Local Development

```bash
# Install dependencies
cd app
pip install -r requirements.txt

# Run locally
python main.py

# Test endpoints
curl http://localhost:8080/health
curl -X POST http://localhost:8080/analyze -H "Content-Type: application/json" -d '{"text": "test"}'
```

## Setup and Deployment Instructions

### Prerequisites
- Google Cloud SDK installed and configured
- GitHub account with repository access
- Terraform installed (for infrastructure management)

### Step-by-Step Setup

#### 1. Google Cloud Project Setup

```bash
# Create new project (replace with unique ID)
export PROJECT_ID="your-unique-project-id"
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Set up billing (required for Cloud Run)
# Visit: https://console.cloud.google.com/billing
```

#### 2. Artifact Registry Setup

```bash
# Create Docker repository
gcloud artifacts repositories create text-analyzer \
    --repository-format=docker \
    --location=us-central1 \
    --description="Container images for text analyzer"

# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev
```

#### 3. Service Accounts and IAM

```bash
# Create GitHub Actions service account
gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions CI/CD" \
    --description="Automated deployment service account"

# Create runtime service account
gcloud iam service-accounts create text-analyzer-runtime \
    --display-name="Text Analyzer Runtime" \
    --description="Application runtime service account"

# Grant necessary permissions to GitHub Actions SA
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Allow GitHub Actions SA to use runtime SA
gcloud iam service-accounts add-iam-policy-binding \
    text-analyzer-runtime@$PROJECT_ID.iam.gserviceaccount.com \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"
```

#### 4. Generate and Secure Service Account Key

```bash
# Generate service account key
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com

# Display key content for GitHub Secrets (copy this output)
echo "Copy this content to GitHub Secret 'GCP_SA_KEY':"
cat github-actions-key.json

# Securely delete the local key file
shred -vfz -n 3 github-actions-key.json
```

#### 5. GitHub Repository Configuration

**Fork/Clone Repository**:
```bash
git clone https://github.com/YOUR_USERNAME/cloud-text-analyzer.git
cd cloud-text-analyzer
```

**Configure GitHub Secrets**:
1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret" and add:
   - **Name**: `GCP_PROJECT_ID`
   - **Value**: Your project ID (e.g., `your-unique-project-id`)
4. Click "New repository secret" and add:
   - **Name**: `GCP_SA_KEY`
   - **Value**: Complete JSON content from the key file

#### 6. Terraform Configuration

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars file
cat > terraform.tfvars << EOF
project_id = "$PROJECT_ID"
region     = "us-central1"
EOF

# Plan infrastructure
terraform plan

# Apply infrastructure (optional - GitHub Actions will do this)
terraform apply
```

#### 7. Deploy Application

**Automatic Deployment**:
```bash
# Push to main branch triggers deployment
git add .
git commit -m "Initial deployment setup"
git push origin main
```

**Manual Deployment** (for testing):
```bash
# Build and push container
cd app
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/text-analyzer/app:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/text-analyzer/app:latest

# Deploy to Cloud Run
gcloud run deploy text-analyzer \
    --image=us-central1-docker.pkg.dev/$PROJECT_ID/text-analyzer/app:latest \
    --region=us-central1 \
    --service-account=text-analyzer-runtime@$PROJECT_ID.iam.gserviceaccount.com \
    --no-allow-unauthenticated
```

#### 8. Verification

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe text-analyzer \
    --region=us-central1 \
    --format="value(status.url)")

# Test health endpoint (requires authentication)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     $SERVICE_URL/health

# Test analyze endpoint
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"text": "Hello, secure world!"}' \
     $SERVICE_URL/analyze
```

### Troubleshooting

**Common Issues**:

1. **Authentication Errors**:
   ```bash
   # Verify service account permissions
   gcloud projects get-iam-policy $PROJECT_ID \
       --flatten="bindings[].members" \
       --filter="bindings.members:github-actions@$PROJECT_ID.iam.gserviceaccount.com"
   ```

2. **Container Build Failures**:
   ```bash
   # Check Cloud Build logs
   gcloud builds list --limit=5
   ```

3. **Deployment Issues**:
   ```bash
   # Check Cloud Run service logs
   gcloud run services logs read text-analyzer --region=us-central1
   ```

### CI/CD Pipeline Explanation

**GitHub Actions Workflow**:
1. **Trigger**: Push to main branch or pull request
2. **Authentication**: Uses service account key from GitHub Secrets
3. **Build**: Creates container image with security hardening
4. **Push**: Uploads image to Artifact Registry
5. **Deploy**: Updates Cloud Run service with new image
6. **Terraform**: Manages infrastructure as code

**Security in CI/CD**:
- No secrets in code repository
- Service account with minimal permissions
- Immutable container images
- Infrastructure as code for consistency

## Testing and Usage

**POST /analyze**
```json
{
  "text": "Hello world"
}
```

Response:
```json
{
  "original_text": "Hello world",
  "word_count": 2,
  "character_count": 11
}
```

## Security

### Design Decisions

**Why Cloud Run?**
- **Serverless Security**: Automatic patching and infrastructure management by Google
- **Built-in Authentication**: Native IAM integration eliminates custom auth implementation
- **Network Isolation**: Private services by default with configurable ingress controls
- **Auto-scaling**: Reduces attack surface by scaling to zero when not in use

**Authentication Strategy**
- **IAM-based Access Control**: Cloud Run service requires valid Google Cloud IAM credentials
- **Service-to-Service Auth**: Uses Google's service account tokens for internal communication
- **No API Keys**: Eliminates risk of hardcoded credentials in application code

**Container Security**
- **Non-root User**: Application runs as unprivileged user (UID 1000) to limit container escape impact
- **Minimal Base Image**: Uses distroless Python image to reduce attack surface
- **Read-only Filesystem**: Container filesystem mounted as read-only where possible

**Network Security**
- **Private Ingress**: Service configured with `ingress: INGRESS_TRAFFIC_INTERNAL_ONLY`
- **VPC Connector**: Routes traffic through private Google Cloud network
- **No Public Internet**: Application cannot make outbound internet calls

### Security Implementation

#### 1. Service Account Setup (Least Privilege)

```bash
# Create dedicated service account for GitHub Actions
gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions CI/CD" \
    --description="Service account for automated deployments"

# Grant minimal required permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.admin"  # Deploy Cloud Run services

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.admin"  # Push/pull container images

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"  # Impersonate service accounts
```

#### 2. Secure Credential Management

**Generate Service Account Key (One-time Setup)**
```bash
# Create key file (keep this secure!)
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Verify key creation
ls -la github-actions-key.json
```

**GitHub Repository Secrets Setup**
1. Navigate to your GitHub repository
2. Go to Settings → Secrets and variables → Actions
3. Add the following secrets:
   - `GCP_PROJECT_ID`: Your Google Cloud project ID
   - `GCP_SA_KEY`: Complete contents of `github-actions-key.json`

**Important**: Delete the local key file after uploading to GitHub:
```bash
rm github-actions-key.json
```

#### 3. Runtime Service Account (Application)

```bash
# Create runtime service account with minimal permissions
gcloud iam service-accounts create text-analyzer-runtime \
    --display-name="Text Analyzer Runtime" \
    --description="Service account for running the application"

# No additional roles needed - application doesn't access GCP services
```

#### 4. Network Security Configuration

**VPC Connector Setup** (if internal access needed):
```bash
# Create VPC connector for private networking
gcloud compute networks vpc-access connectors create text-analyzer-connector \
    --region=us-central1 \
    --subnet=default \
    --subnet-project=YOUR_PROJECT_ID \
    --min-instances=2 \
    --max-instances=3
```

#### 5. Container Security Hardening

**Dockerfile Security Practices**:
```dockerfile
# Use distroless base image
FROM gcr.io/distroless/python3-debian11

# Create non-root user
USER 1000:1000

# Set read-only root filesystem
# (configured in Cloud Run deployment)
```

**Cloud Run Security Configuration**:
```yaml
# In terraform/main.tf
resource "google_cloud_run_service" "text_analyzer" {
  # ... other configuration
  
  template {
    metadata {
      annotations = {
        "run.googleapis.com/execution-environment" = "gen2"
        "run.googleapis.com/cpu-throttling"       = "false"
      }
    }
    
    spec {
      service_account_name = google_service_account.runtime.email
      
      containers {
        # Security context
        security_context {
          run_as_user = 1000
        }
        
        # Resource limits (security best practice)
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Restrict ingress to internal traffic only
resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.text_analyzer.location
  project  = google_cloud_run_service.text_analyzer.project
  service  = google_cloud_run_service.text_analyzer.name
  
  # Only allow authenticated requests
  policy_data = data.google_iam_policy.noauth.policy_data
}
```

### Security Verification

**Test Authentication**:
```bash
# This should fail (no authentication)
curl https://YOUR_SERVICE_URL/health

# This should succeed (with proper auth)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
     https://YOUR_SERVICE_URL/health
```

**Verify Network Isolation**:
```bash
# Check service configuration
gcloud run services describe text-analyzer \
    --region=us-central1 \
    --format="value(spec.template.metadata.annotations)"
```

### Incident Response

**Key Rotation**:
```bash
# Rotate service account keys
gcloud iam service-accounts keys create new-key.json \
    --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Update GitHub secret, then delete old key
gcloud iam service-accounts keys delete OLD_KEY_ID \
    --iam-account=github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

**Security Monitoring**:
- Enable Cloud Audit Logs for all IAM and Cloud Run operations
- Set up alerting for unauthorized access attempts
- Monitor service account key usage in Cloud Console